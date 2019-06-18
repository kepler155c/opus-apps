local neural   = require('neural.interface')

local device   = _G.device
local gps      = _G.gps
local os       = _G.os
local parallel = _G.parallel

neural.assertModules({
	'plethora:glasses',
	'plethora:introspection',
	'plethora:sensor',
})

local function getPoint()
	local pt = { gps.locate() }
	if pt[1] then
		return {
			x = pt[1],
			y = pt[2],
			z = pt[3],
		}
	end
end

local projecting = { }
local offset = getPoint() or error('GPS not found')

local canvas = neural.canvas3d().create({
	-(offset.x % 1),
	-(offset.y % 1),
	-(offset.z % 1)
})

local function update(scanned)
	for _, b in pairs(scanned) do
		if not projecting[b.id] then
			local box

			local x = b.x - math.floor(offset.x)
			local y = b.y - math.floor(offset.y)
			local z = b.z - math.floor(offset.z)

			-- items are centered at the mid-point of the cube
			-- boxes are aligned to the top corner - sigh
			if b.path then
				box = canvas.addBox(x + .4, y + .4, z + .4, .2, .2, .2, 0xa0902080)
			elseif b.name then
				pcall(function()
					box = canvas.addItem({ x + .5, y + .5, z + .5 }, b.name, b.damage or b.metadata, .5)
				end)
			end
			if not box then
				box = canvas.addBox(x, y, z, 1, 1, 1, 0x8080ff30)
			end
			if box then
				box.setDepthTested(false)
			end
			projecting[b.id] = box
		end
	end

	for id, box in pairs(projecting) do
		if not scanned[id] then
			box.remove()
			projecting[id] = nil
		end
	end
end

local scanned = { }
local dirty

local function processMessage(msg)
	if msg.type == 'canvas_clear' then
		scanned = { }
		projecting = { }
		canvas.clear()

	elseif msg.type == 'canvas_remove' then
		for _, v in pairs(msg.data) do
			v.id = table.concat({ v.x, v.y, v.z }, ':')
			scanned[v.id] = nil
		end
		dirty = true

	elseif msg.type == 'canvas_update' then
		scanned = { }
		for _, v in pairs(msg.data) do
			v.id = table.concat({ v.x, v.y, v.z }, ':')
			scanned[v.id] = v
		end
		dirty = true

	elseif msg.type == 'canvas_barrier' then
		for _, v in pairs(msg.data) do
			v.id = table.concat({ v.x, v.y, v.z }, ':')
			if projecting[v.id] then
				projecting[v.id].remove()
				projecting[v.id] = nil
			end
			v.name = 'minecraft:barrier'
			v.damage = 0
			scanned[v.id] = v
		end
		dirty = true

	elseif msg.type == 'canvas_path' then
		for k, v in pairs(scanned or { }) do
			if v.path then
				scanned[k] = nil
			end
		end

		for _, v in pairs(msg.data) do
			v.path = true
			v.id = table.concat({ v.x, v.y, v.z }, ':')
			scanned[v.id] = v
		end
		dirty = true
	end
end

local function recenter()
	while true do
		os.sleep(3)

		local pos = getPoint()

		if pos then
			if math.abs(pos.x - offset.x) +
				math.abs(pos.y - offset.y) +
				math.abs(pos.z - offset.z) > 64 then
				for _, box in pairs(projecting) do
					box.remove()
				end
				projecting = { }
				offset = pos
				canvas.recenter({
					-(offset.x % 1),
					-(offset.y % 1),
					-(offset.z % 1)
				})

				update(scanned)
			end
		end
	end
end

local function queueListener()
	while true do
		local _, msg = os.pullEvent('canvas_message')
		processMessage(msg)
	end
end

local function modemListener()
	device.wireless_modem.open(3773)
	while true do
		local _, _, dport, _, msg = os.pullEvent('modem_message')
		if dport == 3773 and type(msg) == 'table' then
			processMessage(msg)
		end
	end
end

local s, m = pcall(function()
	parallel.waitForAny(
		queueListener,
		modemListener,
		recenter,
		function()
			while true do
				if dirty then
					dirty = false
					update(scanned)
				end
				os.sleep(1)
			end
		end
	)
end)

canvas.clear()
device.wireless_modem.close(3773)

if not s and m then
	_G.printError(m)
end
