local Event    = require('event')
local itemDB   = require('core.itemDB')
local UI       = require('ui')
local Util     = require('util')

local device   = _G.device
local gps      = _G.gps
local parallel = _G.parallel

local glasses = device['plethora:glasses']
local scanner = device['plethora:scanner'] or
	error('Plethora scanner must be equipped')

local target
local projecting = { }

local function getPoint()
	local pt = { gps.locate() }
	return {
		x = pt[1],
		y = pt[2],
		z = pt[3],
	}
end

local offset = getPoint()
local canvas = glasses and glasses.canvas3d().create()
--{ -(offset.x % 1), -(offset.y % 1), -(offset.z % 1) }

UI:configure('Scanner', ...)

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Scan',   event = 'scan' },
			{ text = 'Totals', event = 'totals' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		columns = {
			{ heading = 'Name',  key = 'displayName' },
			{ heading = 'Count', key = 'count', width = 5, align = 'right' },
		},
		sortColumn = 'displayName',
	},
	accelerators = {
		q = 'quit',
	},
	detail = UI.SlideOut {
		menuBar = UI.MenuBar {
			buttons = {
				{ text = 'Projector', event = 'project' },
				{ text = 'Cancel',    event = 'cancel'  },
			},
		},
		grid = UI.ScrollingGrid {
			y = 2, ey = -2,
			columns = {
				{ heading = 'Name', key = 'name' },
				{ heading = 'Dmg',  key = 'metadata', width = 3 },
				{ heading = '  X',  key = 'x', width = 3, align = 'right' },
				{ heading = '  Y',  key = 'y', width = 3, align = 'right' },
				{ heading = '  Z',  key = 'z', width = 3, align = 'right' },
			},
			sortColumn = 'name',
		},
	},
}

function page:scan()
	local throttle = Util.throttle()
	self.blocks = scanner:scan()

	self.grid:setValues(Util.reduce(self.blocks,
		function(acc, b)
			local entry = itemDB:get(table.concat({ b.name, b.metadata }, ':'))
			if not entry then
				local meta = scanner.getBlockMeta(b.x, b.y, b.z)
				entry = itemDB:add({
					name = meta.name,
					displayName = meta.displayName,
					damage = meta.metadata,
				})
			end
			b.key = entry.displayName
			if acc[b.key] then
				acc[b.key].count = acc[b.key].count + 1
			else
				entry = Util.shallowCopy(entry)
				entry.lname = entry.displayName:lower()
				entry.count = 1
				entry.key = b.key
				acc[b.key] = entry
			end
			throttle()
			return acc
		end,
		{ }))

	itemDB:flush()

	self.grid:draw()
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.count = Util.toBytes(row.count)
	return row
end

function page.detail:show(blocks, entry)
	self.grid:setValues(Util.filter(blocks, function(b) return b.key == entry.key end))
	return UI.SlideOut.show(self)
end

function page.detail:eventHandler(event)
	if event.type == 'grid_select' then
		target = event.selected
	else
		return UI.SlideOut.eventHandler(self, event)
	end
	return true
end

function page:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'scan' then
		self:scan()

	elseif event.type == 'grid_select' then
		self.detail:show(self.blocks, self.grid:getSelected())

	elseif event.type == 'cancel' then
		if canvas then
			canvas.clear()
			target = nil
			projecting = { }
		end
		self.detail:hide()
	end

	UI.Page.eventHandler(self, event)
end

if canvas then
	Event.onInterval(.5, function()
		if target then
			local pos, scanned

			parallel.waitForAll(
				function()
					pos = getPoint()
				end,
				function()
					scanned = scanner.scan()
				end
			)
			local blocks = Util.reduce(scanned, function(acc, b)
				if b.name == target.name and b.metadata == target.metadata then
					b.wx = math.floor(pos.x + b.x)
					b.wy = math.floor(pos.y + b.y)
					b.wz = math.floor(pos.z + b.z)
					b.id = table.concat({ math.floor(b.wx), math.floor(b.wy), math.floor(b.wz) }, ':')
					acc[b.id] = b
				end
				return acc
			end, { })

			for _, b in pairs(blocks) do
				if not projecting[b.id] then
					projecting[b.id] = b
					b.box = canvas.addBox(
						pos.x - offset.x + b.x + -(pos.x % 1) + .25,
						pos.y - offset.y + b.y + -(pos.y % 1) + .25,
						pos.z - offset.z + b.z + -(pos.z % 1) + .25,
						.5, .5, .5)
					b.box.setDepthTested(false)
				end
			end

			for _, b in pairs(projecting) do
				if not blocks[b.id] then
					projecting[b.id].box.remove()
					projecting[b.id] = nil
				end
			end

--			canvas.recenter({
--					offset.x - pos.x,
--					offset.y - pos.y,
--					offset.z - pos.z,
--				})
		end
	end)
end

UI:setPage(page)
UI:pullEvents()

if canvas then
	canvas:clear()
end
