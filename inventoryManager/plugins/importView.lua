local UI   = require('ui')
local Util = require('util')

local device = _G.device

local importView = UI.Window {
	mtype = 'machine',
	title = 'Import item from machine',
	index = 4,
	grid = UI.ScrollingGrid {
		y = 2, ey = -2,
		columns = {
			{ heading = 'Slot',   key = 'slot', width = 4 },
			{ heading = 'Import', key = 'import' },
		},
		sortColumn = 'slot',
		help = 'Double-click to toggle'
	},
}

function importView:setMachine(machine)
	local m = device[machine.name]

	local t = { }
	for k = 1, m.size() do
		t[k] = { slot = k }
	end

	if machine.imports then
		for k,v in pairs(machine.imports) do
			t[k] = { slot = k, import = v }
		end
	end

	self.grid:setValues(t)
end

function importView:save(machine)
	local t = { }
	for k,v in pairs(self.grid.values) do
		if v.import then
			t[k] = true
		end
	end
	machine.imports = not Util.empty(t) and t or nil
	return true
end

function importView:eventHandler(event)
	if event.type == 'grid_select' then
		event.selected.import = not event.selected.import
		self.grid:draw()
	end
end

UI:getPage('machineWizard').wizard:add({ import = importView })
