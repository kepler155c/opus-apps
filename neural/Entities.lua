local Event   = require('event')
local Project = require('neural.project')
local UI      = require('ui')
local Util    = require('util')

local device = _G.device

local ni = device.neuralInterface
local sensor = ni or device['plethora:sensor']
if not sensor or not sensor.sense then
	error('Plethora sensor must be equipped')
end

local canvas = ni.canvas()
canvas.clear()

Project:init(canvas)

UI:configure('Entities', ...)

local page = UI.Page {
	grid = UI.ScrollingGrid {
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
	row.x = math.floor(row.x)
	row.y = math.floor(row.y)
	row.z = math.floor(row.z)
	return row
end

function page:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()
	end
	UI.Page.eventHandler(self, event)
end

Event.onInterval(1, function()
	page.grid:setValues(sensor.sense())
	page.grid:draw()
	page:sync()
	local meta = ni.getMetaOwner()
	canvas:clear()
	for _, b in pairs(page.grid.values) do
		if b.id ~= meta.id then
			Project:draw(meta, b, 'X', 0xFFDF50AA)
		end
	end
end)

UI:setPage(page)
UI:pullEvents()

canvas:clear()
