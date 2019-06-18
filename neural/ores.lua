-- Original concept by
--   HydroNitrogen (a.k.a. GoogleTech, Wendelstein7)
--   Bram S. (a.k.a ThatBram0101, bram0101)
-- see: https://energetic.pw/computercraft/ore3d/assets/ore3d.lua

-- Updated to use new(ish) canvas3d

local gps        = _G.gps
local keys       = _G.keys
local os         = _G.os
local parallel   = _G.parallel
local peripheral = _G.peripheral

local function showRequirements(missing)
	print([[A neural interface is required containing:
 * Overlay glasses
 * Scanner
 * Modem
]])
	error('Missing: ' .. missing)
end

local modules = peripheral.find('neuralInterface')
if not modules then
	showRequirements('Neural interface')
elseif not modules.canvas then
	showRequirements('Overlay glasses')
elseif not modules.scan then
	showRequirements('Scanner module')
end

-- size of displayed block
local BLOCK_SIZE = .5

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

local targets = {
	["minecraft:emerald_ore"]      = { "minecraft:emerald_ore", 0 },
	["minecraft:diamond_ore"]      = { "minecraft:diamond_ore", 0 },
	["minecraft:gold_ore"]         = { "minecraft:gold_ore", 0 },
	["minecraft:redstone_ore"]     = { "minecraft:redstone_ore", 0 },
	["minecraft:lit_redstone_ore"] = { "minecraft:redstone_ore", 0 },
	["minecraft:iron_ore"]         = { "minecraft:iron_ore", 0 },
	["minecraft:lapis_ore"]        = { "minecraft:lapis_ore", 0 },
	["minecraft:coal_ore"]         = { "minecraft:coal_ore", 0 },
	["minecraft:quartz_ore"]       = { "minecraft:quartz_ore", 0 },
	["minecraft:glowstone"]        = { "minecraft:glowstone", 0 },
}
local projecting = { }
local offset = getPoint() or showRequirements('GPS')
local canvas = modules.canvas3d().create({
	-(offset.x % 1) + .5,
	-(offset.y % 1) + .5,
	-(offset.z % 1) + .5 })

local function update()
	while true do
		-- order matters
		local scanned = modules.scan()
		local pos = getPoint()

		if pos then
			if math.abs(pos.x - offset.x) +
				 math.abs(pos.y - offset.y) +
				 math.abs(pos.z - offset.z) > 64 then
				for _, b in pairs(projecting) do
					b.box.remove()
				end
				projecting = { }
				offset = pos
				canvas.recenter({
					-(offset.x % 1) + .5,
					-(offset.y % 1) + .5,
					-(offset.z % 1) + .5 })
			end

			local blocks = { }
			for _, b in pairs(scanned) do
				if targets[b.name] then
					-- track block's world position
					b.id = table.concat({
						math.floor(pos.x + b.x),
						math.floor(pos.y + b.y),
						math.floor(pos.z + b.z) }, ':')
					blocks[b.id] = b
				end
			end

			for _, b in pairs(blocks) do
				if not projecting[b.id] then
					projecting[b.id] = b
					local target = targets[b.name]

					local x = b.x - math.floor(offset.x) + math.floor(pos.x)
					local y = b.y - math.floor(offset.y) + math.floor(pos.y)
					local z = b.z - math.floor(offset.z) + math.floor(pos.z)

					--[[
					b.box = canvas.addFrame({ x, y, z })
					b.box.setDepthTested(false)
					b.box.addItem({ .25, .25 }, target[1], target[2], 2)
					--]]

					b.box = canvas.addItem({ x, y, z }, target[1], target[2], BLOCK_SIZE)
					b.box.setDepthTested(false)
				end
			end

			for _, b in pairs(projecting) do
				if not blocks[b.id] then
					b.box.remove()
					projecting[b.id] = nil
				end
			end
		end

		os.sleep(.5)
	end
end

parallel.waitForAny(
	function()
		print('Ore visualization started')
		print('Press enter to exit')
		while true do
			local e, key = os.pullEventRaw('key')
			if key == keys.enter or e == 'terminate' then
				break
			end
		end
	end,
	update
)

canvas.clear()
