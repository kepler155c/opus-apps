local itemDB = require('core.itemDB')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors
local device = _G.device

local importView = UI.WizardPage {
	title = 'Import item from inventory',
	index = 4,
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
		help = 'Import from this slot',
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

function importView:isValidType(node)
	local m = device[node.name]
	return m and m.pullItems and {
		name = 'Generic Inventory',
		value = 'machine',
		category = 'machine',
		help = 'Chest, furnace... (has an inventory)',
	}
end

function importView:isValidFor(node)
	return node.mtype == 'machine'
end

function importView:setNode(node)
	self.machine = node
	if not self.machine.imports then
		self.machine.imports = { }
	end
	self.grid:setValues(self.machine.imports)

	self.slots.choices = {
		{ name = 'All', value = '*' }
	}

	local m = device[self.machine.name]
	for k = 1, m.size() do
		table.insert(self.slots.choices, { name = k, value = k })
	end
end

function importView.grid:getDisplayValues(row)
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

function importView:eventHandler(event)
	if event.type == 'grid_select' then
		self:emit({
			type = 'edit_filter',
			entry = self.grid:getSelected(),
			callback = function()
				self.grid:update()
				self.grid:draw()
			end,
		})

	elseif event.type == 'add_entry' then
		table.insert(self.machine.imports, {
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

UI:getPage('nodeWizard').wizard:add({ import = importView })
