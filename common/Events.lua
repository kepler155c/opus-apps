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
		getDisplayValues = function(_, row)
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
		end,
		draw = function(self)
			self:adjustWidth()
			UI.Grid.draw(self)
		end,
	},
	accelerators = {
		f = 'filter',
		p = 'toggle',
		r = 'reset',
		c = 'clear',
		[ 'control-q' ] = 'quit',
	},
	filtered = { },
	eventHandler = function(self, event)
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
			UI:quit()

		else
			return UI.Page.eventHandler(self, event)
		end
		return true
	end,
}

local updated = false
local timerId = os.startTimer(1)

Event.addRoutine(function()
	while true do
		local _, id = os.pullEvent('timer')
		if id == timerId then
			if updated then
				while #page.grid.values > 100 do -- page.grid.height do
					table.remove(page.grid.values, 100) -- #page.grid.values)
				end
				updated = false
				page.grid:update()
				page.grid:draw()
				page:sync()
			end
			timerId = os.startTimer(1)
		end
	end
end)

local hookFunction = function(event, e)
	if not page.filtered[event] and not page.paused and not (event == 'timer' and e[1] == timerId) then
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

UI:setPage(page)
UI:start()

kernel.unhook('*', hookFunction)
