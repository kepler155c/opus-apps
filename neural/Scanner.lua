local Event   = require('event')
local itemDB  = require('core.itemDB')
local Project = require('neural.project')
local UI      = require('ui')
local Util    = require('util')

local peripheral = _G.peripheral

local scanner =
	peripheral.find('neuralInterface') or
	peripheral.find('plethora:scanner') or
	peripheral.find('manipulator')

	if not scanner or not scanner.scan then
	error('Plethora scanner must be equipped')
end

local projecting

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
		projecting = event.selected
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
		if Project.canvas then
			Project.canvas.clear()
			projecting = nil
		end
		self.detail:hide()
	end

	UI.Page.eventHandler(self, event)
end

if scanner.canvas then
	Project:init(scanner.canvas())

	Event.onInterval(.5, function()
		if projecting then
			local blocks = scanner.scan()
			local pts = Util.filter(blocks, function(b)
					return b.name == projecting.name and b.metadata == projecting.metadata
				end)
			Project.canvas.clear()
			Project:drawPoints(scanner.getMetaOwner(), pts, true, 0xFFDF50AA)
		end
	end)
end

UI:setPage(page)
UI:pullEvents()

if projecting then
	Project.canvas:clear()
end
