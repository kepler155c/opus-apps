local Event = require('opus.event')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local multishell = _ENV.multishell
local kernel     = _G.kernel

UI:configure('Events', ...)

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Filter', event = 'filter' },
			{ text = 'Reset',  event = 'reset'  },
			{ text = 'Pause ', event = 'toggle', name = 'pauseButton' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		columns = {
			{ key = 'event' },
			{ key = 'p1' },
			{ key = 'p2' },
			{ key = 'p3' },
			{ key = 'p4' },
			{ key = 'p5' },
		},
		autospace = true,
		disableHeader = true,
	},
	accelerators = {
		f = 'filter',
		p = 'toggle',
		r = 'reset',
		c = 'clear',
		[ 'control-q' ] = 'quit',
	},
	filtered = { },
}

function page:eventHandler(event)

	if event.type == 'filter' then
		local entry = self.grid:getSelected()
		self.filtered[entry.event] = true

	elseif event.type == 'toggle' then
		self.paused = not self.paused
		if self.paused then
			self.menuBar.pauseButton.text = 'Resume'
		else
			self.menuBar.pauseButton.text = 'Pause '
		end
		self.menuBar:draw()

	elseif event.type == 'grid_select' then
		multishell.openTab({
			path = 'sys/apps/Lua.lua',
			args = { event.selected },
			focused = true,
		})

	elseif event.type == 'reset' then
		self.filtered = { }
		self.grid:setValues({ })
		self.grid:draw()
		if self.paused then
			self:emit({ type = 'toggle' })
		end

	elseif event.type == 'clear' then
		self.grid:setValues({ })
		self.grid:draw()

	elseif event.type == 'quit' then
		UI:exitPullEvents()

	--[[
	elseif event.type == 'focus_change' then
		if event.focused == self.grid then
			if not self.paused then
				self:emit({ type = 'toggle' })
			end
		end
	--]]

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)

	local function tovalue(s)
		if type(s) == 'table' then
			return 'table'
		end
		return s
	end

	for k,v in pairs(row) do
		row[k] = tovalue(v)
	end

	return row
end

function page.grid:draw()
	self:adjustWidth()
	UI.Grid.draw(self)
end

local updated = false
local hookFunction = function(event, e)
	if not page.filtered[event] and not page.paused then
		updated = true
		table.insert(page.grid.values, 1, {
			event = event,
			p1 = e[1],
			p2 = e[2],
			p3 = e[3],
			p4 = e[4],
			p5 = e[5],
		})
	end
end

kernel.hook('*', hookFunction)

Event.onInterval(1, function()
	if updated then
		while #page.grid.values > 100 do -- page.grid.height do
			table.remove(page.grid.values, 100) -- #page.grid.values)
		end
		updated = false
		page.grid:update()
		page.grid:draw()
		page:sync()
	end
end)

UI:setPage(page)
UI:pullEvents()

kernel.unhook('*', hookFunction)
