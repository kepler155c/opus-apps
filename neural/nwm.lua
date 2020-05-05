--[[
	A simplistic window manager for glasses.
	TODO: support moving windows via mouse drag.
]]

local Config  = require('opus.config')
local Glasses = require('neural.glasses')
local UI      = require('opus.ui')
local Util    = require('opus.util')

local kernel     = _G.kernel
local multishell = _ENV.multishell
local shell      = _ENV.shell

local config = Config.load('nwm', { session = { } })

-- TODO: figure out how to better define scaling
local scale = .5
local xs, ys = 6 * scale, 9 * scale

local events = {
	glasses_click = 'mouse_click',
	glasses_up = 'mouse_up',
	glasses_drag = 'mouse_drag',
	glasses_scroll = 'mouse_scroll',
}

local function hook(e, eventData)
	local currentTab = kernel.getFocused()
	local x = math.floor(eventData[2] / xs)
	local y = math.floor(eventData[3] / ys)
	local clickedTab

	for _,tab in ipairs(kernel.routines) do
		if tab.window.type == 'glasses' then
			local wx, wy = tab.window.getPosition()
			local ww, wh = tab.window.getSize()

			if x >= wx and x <= wx + ww and y >= wy and y <= wy + wh then
				clickedTab = tab
				x = x - wx
				y = y - wy
				break
			end
		end
	end

	if clickedTab then
		if clickedTab ~= currentTab then
			clickedTab.window.raise()
			multishell.setFocus(clickedTab.uid)
		end

		kernel.event(events[e], {
			eventData[1], x, y, clickedTab.window.side,
		})

	end
	return true
end

local hookEvents = Util.keys(events)
kernel.hook(hookEvents, hook)

local function run(args)
	local window = Glasses.create(args)

	multishell.openTab({
		path = args.path,
		args = args.args,
		hidden = true,
		onDestroy = function()
			Util.removeByValue(config.session, args)
			Config.update('nwm', config)
			window.destroy()
		end,
		window = window,
	})
end

UI:setPage(UI.Page {
	form = UI.Form {
		values = {
			x = 1, y = 25, width = 51, height = 19,
			opacity = 255,
		},
		UI.TextEntry {
			formKey = 'run', formLabel = 'Run', required = true,
		},
		UI.Slider {
			min = 0, max = 255,
			formLabel = 'Opacity', formKey = 'opacity', formIndex = 3,
		},
		UI.Text {
			x = 10, y = 5,
			textColor = 'yellow',
			value = ' x       y'
		},
		UI.TextEntry {
			x = 10, y = 6, width = 7, limit = 3,
			transform = 'number',
			formKey = 'x', required = true,
		},
		UI.TextEntry {
			x = 18, y = 6, width = 7, limit = 4,
			transform = 'number',
			formKey = 'y', required = true,
		},
		UI.Text {
			x = 10, y = 8,
			textColor = 'yellow',
			value = ' width   height'
		},
		UI.TextEntry {
			x = 10, y = 9, width = 7, limit = 4,
			transform = 'number',
			formKey = 'width', required = true,
		},
		UI.TextEntry {
			x = 18, y = 9, width = 7, limit = 4,
			transform = 'number',
			formKey = 'height', required = true,
		},
	},
	notification = UI.Notification { },
	eventHandler = function(self, event)
		if event.type == 'form_complete' then
			local opts = Util.shallowCopy(event.values)
			local words = Util.split(opts.run, '(.-) ')
			opts.path = shell.resolveProgram(table.remove(words, 1))
			if not opts.path then
				self.notification:error('Invalid program')
			else
				opts.args = #words > 0 and words
				table.insert(config.session, opts)
				Config.update('nwm', config)
				run(opts)
				self.notification:success('Started program')
			end
		end
		return UI.Page.eventHandler(self, event)
	end,
})

for _,v in pairs(config.session) do
	run(v)
end

UI:start()

kernel.unhook(hookEvents, hook)
