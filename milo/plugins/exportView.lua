local itemDB = require('core.itemDB')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors
local device = _G.device

local exportView = UI.WizardPage {
	title = 'Export item into inventory',
	index = 3,
	grid = UI.ScrollingGrid {
		x = 2, ex = -6, y = 2, ey = -4,
		columns = {
			{ heading = 'Slot',   key = 'slot', width = 4 },
			{ heading = 'Filter', key = 'filter' },
		},
		sortColumn = 'slot',
		help = 'Edit this entry',
		accelerators = {
			delete = 'remove_entry',
		},
	},
	text = UI.Text {
		x = 3, y = -2,
		value = 'Slot',
		textColor = colors.black,
	},
	slots = UI.Chooser {
		x = 8, y = -2,
		width = 7,
		nochoice = 'All',
		help = 'Export to this slot',
	},
	add = UI.Button {
		x = 16, y = -2,
		text = '+', event = 'add_entry', help = 'Add',
	},
	remove = UI.Button {
		x = -4, y = 4,
		text = '-', event = 'remove_entry', help = 'Remove',
	},
}

function exportView:isValidType(node)
	local m = device[node.name]
	return m and m.pullItems and {
		name = 'Generic Inventory',
		value = 'machine',
		category = 'machine',
		help = 'Chest, furnace... (has an inventory)'
	}
end

function exportView:isValidFor(node)
	return node.mtype == 'machine'
end

function exportView:setNode(node)
	self.machine = node
	if not self.machine.exports then
		self.machine.exports = { }
	end
	self.grid:setValues(self.machine.exports)

	self.slots.choices = {
		{ name = 'All', value = '*' }
	}

	local m = device[self.machine.name]
		for k = 1, m.size() do
		table.insert(self.slots.choices, { name = k, value = k })
	end
end

function exportView.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	if not row.filter or Util.empty(row.filter) then
		row.filter = 'none'
	else
		local t = { }
		for key in pairs(row.filter) do
			table.insert(t, itemDB:getName(key))
		end
		row.filter = table.concat(t, ', ')
	end
	return row
end

function exportView:eventHandler(event)
	if event.type == 'grid_select' then
		self:emit({
			type = 'edit_filter',
			entry = self.grid:getSelected(),
			whitelistOnly = true,
			callback = function()
				self.grid:update()
				self.grid:draw()
			end,
		})

	elseif event.type == 'add_entry' then
		table.insert(self.machine.exports, {
			slot = self.slots.value or '*',
			filter = { },
		})
		self.grid:update()
		self.grid:draw()

	elseif event.type == 'remove_entry' then
		local row = self.grid:getSelected()
		if row then
			Util.removeByValue(self.grid.values, row)
			self.grid:update()
			self.grid:draw()
		end
	end
end

UI:getPage('nodeWizard').wizard:add({ export = exportView })
