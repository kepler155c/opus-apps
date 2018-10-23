local itemDB = require('itemDB')
local Lora   = require('lora')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device

local itemSlideout = UI.SlideOut {
	backgroundColor = colors.cyan,
	grid = UI.ScrollingGrid {
		y = 3, ey = -2,
		columns = {
			{ heading = 'Name', key = 'displayName', width = 31 },
			{ heading = 'Qty',  key = 'count'      , width = 5  },
		},
		sortColumn = 'displayName',
	},
	filter = UI.TextEntry {
		x = 2, ex = -2, y = 2,
		limit = 50,
		shadowText = 'filter',
		backgroundColor = colors.lightGray,
		backgroundFocusColor = colors.lightGray,
	},
	button1 = UI.Button {
		x = -14, y = -1,
		text = 'Ok', event = 'accept',
	},
	button2 = UI.Button {
		x = -9, y = -1,
		text = 'Cancel', event = 'collapse',
	},
}

function itemSlideout:filterItems(t, filter)
	if filter then
		local r = {}
		filter = filter:lower()
		for _,v in pairs(t) do
			if string.find(v.lname, filter) then
				table.insert(r, v)
			end
		end
		return r
	end
	return t
end

function itemSlideout.grid:enable()
	if not self.allItems then
		self.allItems = Lora:listItems()
		Lora:mergeResources(self.allItems)
		self:setValues(self.allItems)
	end
	UI.Grid.enable(self)
end

function itemSlideout:eventHandler(event)
	if event.type == 'text_change' and event.element == self.filter then
		local t = self:filterItems(self.grid.allItems, event.text)
		self.grid:setValues(t)
		self.grid:draw()
	end
	return UI.SlideOut.eventHandler(self, event)
end

local exportView = UI.Window {
	mtype = 'machine',
	title = 'Export item into machine',
	index = 3,
	grid = UI.ScrollingGrid {
		x = 2, ex = -6, y = 2, ey = -2,
		columns = {
			{ heading = 'Slot', key = 'slot', width = 4 },
			{ heading = 'Item', key = 'displayName' },
		},
		sortColumn = 'slot',
	},
	add = UI.Button {
		x = -4, y = 4,
		text = '+', event = 'add_export', help = '...',
	},
	remove = UI.Button {
		x = -4, y = 6,
		text = '-', event = 'remove_export', help = '...',
	},
}

function exportView:save(machine)
	machine.exports = not Util.empty(self.grid.values) and self.grid.values or nil
	return true
end

function exportView:setMachine(machine)
	local m = device[machine.name]
	self.slotCount = m.size()
	self.grid:setValues(machine.exports or { })
end

function exportView.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = itemDB:getName(row.name)
	return row
end

function exportView:eventHandler(event)
	if event.type == 'grid_select' or event.type == 'add_export' then
		itemSlideout:show()
	elseif event.type == 'remove_export' then
		local row = self.grid:getSelected()
		if row then
			Util.removeByValue(self.grid.values, row)
			self.grid:update()
			self.grid:draw()
		end
	end
end

UI:getPage('machineWizard'):add({ items = itemSlideout })
UI:getPage('machineWizard').wizard:add({ export = exportView })
