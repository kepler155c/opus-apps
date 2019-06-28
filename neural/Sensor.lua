local Config  = require('opus.config')
local Event   = require('opus.event')
local UI      = require('opus.ui')
local Util    = require('opus.util')

local colors  = _G.colors
local device  = _G.device
local gps     = _G.gps

local glasses = device['plethora:glasses']
local intro   = device['plethora:introspection']
local sensor  = device['plethora:sensor'] or
	error('Plethora sensor must be equipped')

UI:configure('Sensor', ...)

local projecting = { }
local offset
local canvas = glasses and intro and glasses.canvas3d().create()

local config = Config.load('Sensor')

local page = UI.Page {
	tabs = UI.Tabs {
		listing = UI.Tab {
			tabTitle = 'Listing',
			grid = UI.ScrollingGrid {
				columns = {
					{ heading = 'Name', key = 'displayName' },
					{ heading = 'X',    key = 'x', width = 3, align = 'right' },
					{ heading = 'Y',    key = 'y', width = 3, align = 'right' },
					{ heading = 'Z',    key = 'z', width = 3, align = 'right' },
				},
				sortColumn = 'displayName',
			},
		},
		summary = UI.Tab {
			tabTitle = 'Summary',
			grid = UI.ScrollingGrid {
				columns = {
					{ heading = 'Name',  key = 'displayName' },
					{ heading = 'Count', key = 'count', width = 5, align = 'right' },
				},
				sortColumn = 'displayName',
			},
		},
		accelerators = {
			q = 'quit',
		},
	},
}

local listing = page.tabs.listing
local summary = page.tabs.summary

local detail = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Back',      event = 'back', x = -6 },
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
}

local function getPoint()
	local pt = { gps.locate() }
	return {
		x = pt[1],
		y = pt[2],
		z = pt[3],
	}
end

local function project(entities)
	if canvas then
		local pos = getPoint()
		local pts = { }

		if not offset then
			offset = pos
		end

		for _, b in pairs(entities) do
			if b.x then
				pts[table.concat({
					math.floor(pos.x + b.x),
					math.floor(pos.y + b.y),
					math.floor(pos.z + b.z) }, ':')] = b
			end
		end

		for key, b in pairs(pts) do
			if not projecting[key] then
				local box = canvas.addBox(
					pos.x - offset.x + b.x,
					pos.y - offset.y + b.y - .25,
					pos.z - offset.z + b.z,
					.25, .25, .25)
				box.setDepthTested(false)
				projecting[key] = box
			end
		end

		for key, box in pairs(projecting) do
			if not pts[key] then
				box.remove()
				projecting[key] = nil
			end
		end
	end
end

function detail:enable(entity)
	local function update()
		local t = { }
		local meta = sensor.getMetaByID(entity.id) or { }
		for k,v in pairs(meta) do
			if type(v) ~= 'table' then
				table.insert(t, {
					name = k,
					value = type(v) == 'string' and v or tostring(v),
				})
			end
		end
		project({ meta })
		return t
	end

	self.handler = Event.onInterval(.5, function()
		self.grid:setValues(update())
		self.grid:draw()
		self.grid:sync()
	end)

	self.grid:setValues(update())
	return UI.Page.enable(self)
end

function detail:disable()
	if self.handler then
		Event.off(self.handler)
		self.handler = nil
	end
	project({ })
	return UI.Page.disable(self)
end

function detail:eventHandler(event)
	if event.type == 'back' then
		return UI:setPreviousPage()
	end
	return UI.Page.eventHandler(self, event)
end

function listing.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.x = row.x and math.floor(row.x) or ''
	row.y = row.y and math.floor(row.y) or ''
	row.z = row.z and math.floor(row.z) or ''
	return row
end

function listing:enable()
	self.handler = Event.onInterval(.5, function()
		local entities = sensor.sense()
		self.grid:setValues(entities)
		self.grid:draw()
		self:sync()
	end)
	return UI.Tab.enable(self)
end

function listing:disable()
	Event.off(self.handler)
	UI.Tab.disable(self)
end

function listing:eventHandler(event)
	if event.type == 'grid_select' then
		local selected = self.grid:getSelected()
		if selected then
			UI:setPage(detail, selected)
		end
	end

	return UI.Tab.eventHandler(self, event)
end

function summary:enable()
	self.handler = Event.onInterval(.5, function()
		local entities = sensor.sense()

		local t = { }
		local highlight = { }
		for _,v in pairs(entities) do
			if t[v.name] then
				t[v.name].count = t[v.name].count + 1
			else
				t[v.name] = { displayName = v.displayName, count = 1, name = v.name }
			end
			if self.target == v.name then
				table.insert(highlight, v)
			end
		end

		project(highlight)

		self.grid:setValues(t)
		self.grid:draw()
		self:sync()
	end)

	self.target = nil
	return UI.Tab.enable(self)
end

function summary:disable()
	project({ })
	Event.off(self.handler)
	UI.Tab.disable(self)
end

function summary.grid:getRowTextColor(row, selected)
	if row.name == self.parent.target then
    return colors.yellow
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function summary:eventHandler(event)
	if event.type == 'grid_select' then
		local selected = self.grid:getSelected()
		if selected then
			self.target = selected.name
			self.grid:draw()
		end
	end

	return UI.Tab.eventHandler(self, event)
end

function page:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'tab_activate' then
		config.activeTab = event.activated.tabTitle
		Config.update('Sensor', config)
	end

	UI.Page.eventHandler(self, event)
end

if config.activeTab then
	page.tabs:selectTab(Util.find(page.tabs.children, 'tabTitle', config.activeTab))
end

UI:setPage(page)
UI:pullEvents()

if canvas then
	canvas:clear()
end
