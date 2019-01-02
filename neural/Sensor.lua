local Config     = require('config')
local Event      = require('event')
local Mobs       = require('neural.mobs')
local Project    = require('neural.project')
local Sound      = require('sound')
local UI         = require('ui')
local Util       = require('util')

local device     = _G.device
local peripheral = _G.peripheral
local turtle     = _G.turtle

local function equip(side, rawName)
	return turtle and turtle.equip(side, rawName) and peripheral.wrap(side)
end

local lastWarning = os.clock()
local target = nil
local ni = device.neuralInterface
local sensor = ni or
	device['plethora:sensor'] or
	peripheral.find('manipulator') or
	equip('left', 'plethora:module:3')

if not sensor or not sensor.sense then
	error('Plethora sensor must be equipped')
end

UI:configure('Entities', ...)

local config = Config.load('Entities', {
	ignore = { }
})
if not config.ignore then
	config.ignore = { }
end

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Projector', event = 'project' },
			{ text = 'Totals',    event = 'totals'  },
			{ text = 'Ignore',    event = 'ignore'  },
			{ text = 'Details',   event = 'detail'  },
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
	detail = UI.SlideOut {
		menuBar = UI.MenuBar {
			buttons = {
				{ text = 'Projector', event = 'project-target' },
				{ text = 'Back',      event = 'hide', x = -6 },
			},
		},
		grid = UI.ScrollingGrid {
			y = 2,
			columns = {
				{ heading = 'Name',  key = 'name' },
				{ heading = 'Value', key = 'value' },
			},
			sortColumn = 'name',
			autospace = true,
		},
	},
}

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.x = row.x and math.floor(row.x) or ''
	row.y = row.y and math.floor(row.y) or ''
	row.z = math.floor(row.z)
	return row
end

function page.detail:show(entity)
	self.entity = entity  -- to allow for debugging in Lua

	local function update()
		local t = { }
		for k,v in pairs(self.entity) do
			if type(v) ~= 'table' then
				table.insert(t, {
					name = k,
					value = type(v) == 'string' and v or tostring(v),
				})
			end
		end
		return t
	end

	if entity.id then
		self.handler = Event.onInterval(.5, function()
			local e = sensor.getMetaByID(self.entity.id)
			if e then
				self.entity = e
				self.grid:setValues(update())
				self.grid:draw()
				self.grid:sync()
			end
		end)
	end

	self.grid:setValues(update())
	return UI.SlideOut.show(self)
end

function page.detail:hide()
	if self.handler then
		Event.off(self.handler)
		self.handler = nil
	end
	return UI.SlideOut.hide(self)
end

function page:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'totals' then
		config.totals = not config.totals
		Config.update('Entities', config)

	elseif event.type == 'detail' or event.type == 'grid_select' then
		local selected = self.grid:getSelected()
		if selected then
			target = selected.name
			self.detail:show(selected)
		end

	elseif event.type == 'hide' then
		self.detail:hide()

	elseif event.type == 'ignore' then
		local selected = self.grid:getSelected()
		if selected then
			config.ignore[selected.name] = true
		end
		Config.update('Entities', config)

	elseif event.type == 'project' or event.type == 'project-target' then
		if event.type == 'project' then
			target = nil
		end

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
	Util.filterInplace(entities, function(e) return not config.ignore[e.name] end)

	if config.projecting then
		local meta = ni.getMetaOwner()
		Project.canvas:clear()
		local t = entities
		if target then
			t = Util.filter(entities, function(e) return e.name == target end)
		end
		Project:drawPoints(meta, t, 'X', 0xFFDF50AA)
	end

	if os.clock() > lastWarning + 5 then
		if Util.any(entities, function(e) return Mobs.getNames()[e.name] end) then
			lastWarning = os.clock()
			Sound.play('entity.player.breath')
		end
	end

	if config.totals then
		local t = { }
		for _,v in pairs(entities) do
			if t[v.name] then
				t[v.name].z = t[v.name].z + 1
			else
				t[v.name] = { displayName = v.displayName, z = 1, name = v.name }
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
