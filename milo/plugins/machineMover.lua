local Craft  = require('milo.craft2')
local Milo   = require('milo')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors  = _G.colors
local context = Milo:getContext()
local device  = _G.device

local page = UI.Page {
	titleBar = UI.TitleBar { title = 'Reassign Machine' },
	grid = UI.ScrollingGrid {
		y = 2, ey = -4,
		values = context.storage.nodes,
		columns = {
			{                   key = 'suffix',     width = 4, align = 'right' },
			{ heading = 'Name', key = 'displayName' },
			{ heading = 'Type', key = 'mtype',      width = 4 },
			{ heading = 'Pri',  key = 'priority',   width = 3 },
		},
		sortColumn = 'displayName',
		help = 'Select Node',
	},
	accept = UI.Button {
		x = -9, y = -2,
		event = 'grid_select',
		text = 'Accept',
	},
	cancel = UI.Button {
		x = -18, y = -2,
		event = 'cancel',
		text = 'Cancel',
	},
	accelerators = {
		grid_select = 'nextView',
	},
	notification = UI.Notification { },
}

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	local t = { row.name:match(':(.+)_(%d+)$') }
	if #t ~= 2 then
		t = { row.name:match('(.+)_(%d+)$') }
	end
	if t and #t == 2 then
		row.name, row.suffix = table.unpack(t)
		row.name = row.name .. '_' .. row.suffix
	end
	row.displayName = row.displayName or row.name
	return row
end

function page.grid:getRowTextColor(row, selected)
	if row.mtype == 'ignore' then
		return colors.lightGray
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function page:applyFilter()
	local t = Util.filter(context.storage.nodes, function(v)
		return v.mtype == 'ignore' and device[v.name]
	end)

	self.grid:setValues(t)
end

function page:enable(machine)
	self.machine = machine
	self:applyFilter()

	UI.Page.enable(self)
end

function page:eventHandler(event)
	if event.type == 'grid_select' then
		local target = self.grid:getSelected()
		if target then
			local adapter = target.adapter
			local name = target.name
			Util.merge(target, self.machine)
			target.adapter = adapter
			target.name = name

			context.storage.nodes[self.machine.name] = nil
			context.storage:saveConfiguration()

			for k,v in pairs(Craft.machineLookup) do
				if v == self.machine.name then
					Craft.machineLookup[k] = name
				end
				Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)
			end

			UI:setPreviousPage()
		end

	elseif event.type == 'cancel' then
		UI:setPreviousPage()

	else
		return UI.Page.eventHandler(self, event)
	end
end

UI:addPage('machineMover', page)
