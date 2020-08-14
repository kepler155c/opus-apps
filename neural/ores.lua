-- Original concept by
--   HydroNitrogen (a.k.a. GoogleTech, Wendelstein7)
--   Bram S. (a.k.a ThatBram0101, bram0101)
-- see: https://energetic.pw/computercraft/ore3d/assets/ore3d.lua

-- Updated to use new(ish) canvas3d

local Config = require('opus.config')
local GPS    = require('opus.gps')
local UI     = require('opus.ui')
local Util   = require('opus.util')
local itemDB = require('core.itemDB')
local Event  = require('opus.event')
local Angle  = require('neural.angle')

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

local projecting = { }
local offset = GPS.locate() or showRequirements('GPS')
local canvas = modules.canvas3d().create({
	-(offset.x % 1) + .5,
	-(offset.y % 1) + .5,
	-(offset.z % 1) + .5 }
)

local page = UI.Page {
	notification = UI.Notification {},

	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Scan',  event = 'scan' },
			{ text = 'Size',  event = 'size' },
			-- { text = 'Laser',  event = 'laser' }, -- If you dare
		}
	},

	sizeSlide = UI.MiniSlideOut {
		x = -13,
		sizeEntry = UI.TextEntry {
			shadowText = "Block Size",
			accelerators = {enter = 'size_accept'}
		}
	},

	grid = UI.CheckboxGrid {
		y = 2,
		columns = {
			{ heading = 'Count', key = 'count', width = 6, align = 'right' },
			{ heading = 'Name',  key = 'displayName' },
		},
		sortColumn = 'displayName',
	}

}

function page:scan()
	local rawBlocks = modules.scan()
	self.totals = Util.reduce(rawBlocks, function(acc, b)
		if b.name == 'minecraft:air' then return acc end
		b.key = table.concat({ b.name, b.metadata }, ':')
		local entry = acc[b.key]
		if not entry then
			b.displayName = itemDB:getName(b.key)
			b.count = 1
			acc[b.key] = b
		else
			entry.count = entry.count + 1
		end

		return acc
	end,
	Util.reduce(self.targets, function(acc, b)
		local key = table.concat({ b[1], b[2] }, ':')
		acc[key] = {
			displayName = itemDB:getName(key),
			name = b[1],
			metadata = b[2],
			key = key,
			count = 0,
			checked = true,
		}
		return acc
	end, { })
	)
	self.grid:setValues(self.totals)
	self:draw()
end

function page:shootLaser()
	if not modules.fire then self.notification:error("No laser found") return end
	self.notification:info("Shooting...")
	self:sync()
	local targets = Util.filter(modules.scan(), function(b)
		return self.targets[table.concat({ b.name, b.metadata }, ':')]
	end)

	Util.each(targets, function(b)
		local yaw, pitch = Angle.towards(b.x, b.y, b.z)
		if pitch < 40 then -- Avoid shooting the block below you
			modules.fire(yaw, pitch, 3)
		end
	end)
	self.notification:success("Done!")
end

function page:loadConfigs()
	self.blockSize, self.targets = unpack(Config.load('ores', {.5, {}}))
end

function page:saveConfigs()
	Config.update('ores', {self.blockSize, self.targets})
end

function page.grid:getRowTextColor(row, selected)
	return row.checked and colors.yellow or UI.CheckboxGrid.getRowTextColor(self, row, selected)
end

function page:eventHandler(event)
	if event.type == "scan" then
		self.notification:info("Scanning...")
		self:sync()
		self:scan()
		self.notification:success("Done!")
	elseif event.type == "size" then
		self.sizeSlide:show()
	elseif event.type == "size_accept" then
		self.blockSize = tonumber(self.sizeSlide.sizeEntry.value) or self.blockSize
		self.blockSize = math.max(self.blockSize, 0)
		self.sizeSlide.sizeEntry:reset()
		self.sizeSlide:hide()

	elseif event.type == "laser" then
		self:shootLaser()

	elseif event.type == "grid_select" then
		local block = event.selected
		local key = table.concat({ block.name, block.metadata }, ':')
		if block.checked then
			self.targets[key] = {block.name, block.metadata}
		else
			self.targets[key] = nil
		end
		page:saveConfigs()
	else return UI.Page.eventHandler(self, event)
	end
	return true
end

page:loadConfigs()
page:scan()

Event.addRoutine(
	function()
		while true do
			-- order matters
			local scanned = modules.scan()
			local pos = GPS.locate()

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
					if page.targets[table.concat({b.name, b.metadata or 0}, ":")] then
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

						local target = page.targets[table.concat({b.name, b.metadata or 0}, ":")]

						local x = b.x - math.floor(offset.x) + math.floor(pos.x)
						local y = b.y - math.floor(offset.y) + math.floor(pos.y)
						local z = b.z - math.floor(offset.z) + math.floor(pos.z)

						--[[
						b.box = canvas.addFrame({ x, y, z })
						b.box.setDepthTested(false)
						b.box.addItem({ .25, .25 }, target[1], target[2], 2)
						--]]

						b.box = canvas.addItem({ x, y, z }, target[1], target[2], page.blockSize)
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
)

UI:setPage(page)
UI:start()

canvas.clear()
