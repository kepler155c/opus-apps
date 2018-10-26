local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device

local itemSlideout = UI.SlideOut {
	backgroundColor = colors.cyan,
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Save',    event = 'save'    },
			{ text = 'Cancel',  event = 'cancel'  },
			{ text = 'Refresh', event = 'refresh', x = -9 },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2, ey = -6,
		columns = {
			{ heading = 'Name', key = 'displayName', width = 31 },
			{ heading = 'Qty',  key = 'count'      , width = 5  },
		},
		sortColumn = 'displayName',
		help = 'Select item to export',
	},
	filter = UI.TextEntry {
		x = 2, ex = 18, y = -3,
		limit = 50,
		shadowText = 'filter',
		backgroundColor = colors.lightGray,
		backgroundFocusColor = colors.lightGray,
	},
	form = UI.Form {
		x = 21, y = -4, height = 3,
		margin = 1,
		manualControls = true,
		[1] = UI.Chooser {
			width = 7,
			formLabel = 'Slot', formKey = 'slot',
			nochoice = 1,
			help = 'Export into this slot',
		},
		[2] = UI.Chooser {
			width = 7,
			formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
			pruneEmpty = true,
			nochoice = 'No',
			choices = {
				{ name = 'Yes', value = true },
				{ name = 'No', value = false },
			},
			help = 'Ignore damage of item when exporting'
		},
		[3] = UI.Chooser {
			width = 7,
			formLabel = 'Ignore NBT', formKey = 'ignoreNbtHash',
			pruneEmpty = true,
			nochoice = 'No',
			choices = {
				{ name = 'Yes', value = true },
				{ name = 'No', value = false },
			},
			help = 'Ignore NBT of item when exporting'
		},
	},
	statusBar = UI.StatusBar {
		backgroundColor = colors.cyan,
	},
}

function itemSlideout:filterItems(t, filter)
	if filter and #filter > 0 then
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
		self.allItems = Milo:listItems()
		Milo:mergeResources(self.allItems)
		self:setValues(self.allItems)
	end
	UI.Grid.enable(self)
end

function itemSlideout:show(machine, entry, callback)
	self.entry = entry
	self.callback = callback

	self.form.choices = { }
	local m = device[machine.name]
	for k = 1, m.size() do
		table.insert(self.form[1].choices, {
			name = k,
			value = k,
		})
	end

	if not entry.slot then
		entry.slot = 1
	end
	self.form:setValues(entry)

	UI.SlideOut.show(self)
	self:setFocus(self.filter)
	--self.filter:focus()
end

function itemSlideout:eventHandler(event)
	if event.type == 'text_change' then
		local t = self:filterItems(self.grid.allItems, event.text)
		self.grid:setValues(t)
		self.grid:draw()

	elseif event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help)

	elseif event.type == 'save' then
		local selected = self.grid:getSelected()
		if not selected then
			self.statusBar:setStatus('Select an item to export')
		else
			self.form:save()
			self.form.values.name = itemDB:makeKey(selected)
			self:hide()
			self.callback()
		end

	elseif event.type == 'cancel' then
		self:hide()

	elseif event.type == 'refresh' then
		self.allItems = Milo:listItems()
		Milo:mergeResources(self.allItems)
		local t = self:filterItems(self.allItems, self.filter.value)
		self.grid:setValues(t)
		self.grid:draw()
		self.filter:focus()
	else
		return UI.SlideOut.eventHandler(self, event)
	end
	return true
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
	self.machine = machine
	if not self.machine.exports then
		self.machine.exports = { }
	end
	self.grid:setValues(machine.exports)
end

function exportView.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = itemDB:getName(row.name)
	return row
end

function exportView:eventHandler(event)
	if event.type == 'grid_select' then
		itemSlideout:show(self.machine, self.grid:getSelected(), function()
			self.grid:update()
			self.grid:draw()
		end)

	elseif event.type == 'add_export' then
		local export = { }
		itemSlideout:show(self.machine, export, function()
			table.insert(self.machine.exports, export)
			self.grid:update()
			self.grid:draw()
		end)

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
