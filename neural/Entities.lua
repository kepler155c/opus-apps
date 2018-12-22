local Config  = require('config')
local Event   = require('event')
local Project = require('neural.project')
local UI      = require('ui')
local Util    = require('util')

local device     = _G.device
local peripheral = _G.peripheral

local ni = device.neuralInterface
local sensor = ni or device['plethora:sensor'] or peripheral.find('manipulator')
if not sensor or not sensor.sense then
	error('Plethora sensor must be equipped')
end

local id = sensor.getID and sensor.getID() or ''

UI:configure('Entities', ...)

local config = Config.load('Entities', { })

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Projector', event = 'project' },
			{ text = 'Totals',    event = 'totals'  },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		columns = {
			{ heading = 'Name', key = 'displayName' },
			{ heading = '  X',    key = 'x', width = 3, justify = 'right' },
			{ heading = '  Y',    key = 'y', width = 3, justify = 'right' },
			{ heading = '  Z',    key = 'z', width = 3, justify = 'right' },
		},
		values = sensor.sense(),
		sortColumn = 'displayName',
	},
	accelerators = {
		q = 'quit',
	},
}

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.x = row.x and math.floor(row.x) or ''
	row.y = row.y and math.floor(row.y) or ''
	row.z = math.floor(row.z)
	return row
end

function page:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'totals' then
		config.totals = not config.totals
		Config.update('Entities', config)

	elseif event.type == 'project' then
		config.projecting = not config.projecting
		if config.projecting then
			Project:init(ni.canvas())
		else
			Project.canvas:clear()
		end
		Config.update('Entities', config)
	end

	UI.Page.eventHandler(self, event)
end

Event.onInterval(.5, function()
	local entities = sensor.sense()
	Util.filterInplace(entities, function(e) return e.id ~= id end)

	if config.projecting then
		local meta = ni.getMetaOwner()
		Project.canvas:clear()
		Project:drawPoints(meta, entities, 'X', 0xFFDF50AA)
	end

	if config.totals then
		local t = { }
		for _,v in pairs(entities) do
			if t[v.displayName] then
				t[v.displayName].z = t[v.displayName].z + 1
			else
				t[v.displayName] = { displayName = v.displayName, z = 1 }
			end
		end
		entities = t
	end

	page.grid:setValues(entities)
	page.grid:draw()
	page:sync()
end)

if config.projecting then
	Project:init(ni.canvas())
end

UI:setPage(page)
UI:pullEvents()

if config.projecting then
	Project.canvas:clear()
end
