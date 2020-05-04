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

local sandbox = Util.shallowCopy(_ENV)

-- TODO: figure out how to better define scaling
local scale = .5
local xs, ys = 6 * scale, 9 * scale

local events = {
	glasses_click = 'mouse_click',
	glasses_up = 'mouse_up',
	glasses_drag = 'mouse_drag',
	glasses_scroll = 'mouse_scroll',
}

local hookEvents = { 'glasses_click', 'glasses_up', 'glasses_drag', 'glasses_scroll' }

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

local config = Config.load('nwm', { session = { } })

local function run(args)
	local window = Glasses.create('glasses', args.x, args.y, args.w, args.h)

	local env = Util.shallowCopy(sandbox)
	_G.requireInjector(env)

	multishell.openTab({
		path = args.path,
		args = args.args,
		env = env,
		focused = false,
		hidden = true,
		onDestroy = function()
			Util.removeByValue(config.session, args)
			Config.update('nwm', config)
			window.destroy()
		end,
		window = window,
	})
end

kernel.hook(hookEvents, hook)

UI:setPage(UI.Page {
	form = UI.Form {
		values = {
			x = 1, y = 25, w = 51, h = 19,
		},
		path = UI.TextEntry {
			y = 5,
			formKey = 'path', formLabel = 'Run', required = true,
		},
		args = UI.TextEntry {
			y = 7,
			formKey = 'args', formLabel = 'Args',
		},
		UI.Text {
			x = 7, y = 5,
			textColor = 'yellow',
			value = ' x       y'
		},
		wx = UI.TextEntry {
			x = 7, y = 6, width = 7, limit = 3,
			transform = 'number',
			formKey = 'x', required = true,
		},
		wy = UI.TextEntry {
			x = 15, y = 6, width = 7, limit = 4,
			transform = 'number',
			formKey = 'y', required = true,
		},
		UI.Text {
			x = 7, y = 8,
			textColor = 'yellow',
			value = ' width   height'
		},
		ww = UI.TextEntry {
			x = 7, y = 9, width = 7, limit = 4,
			transform = 'number',
			formKey = 'w', required = true,
		},
		wh = UI.TextEntry {
			x = 15, y = 9, width = 7, limit = 4,
			transform = 'number',
			formKey = 'h', required = true,
		},
	},
	notification = UI.Notification { },
	eventHandler = function(self, event)
		if event.type == 'form_complete' then
			local args = Util.shallowCopy(event.values)
			args.path = shell.resolveProgram(args.path)
			if not args.path then
				self.notification:error('Invalid program')
			else
				if args.args then
					args.args = Util.split(args.args, '(.-) ')
				end
				table.insert(config.session, args)
				Config.update('nwm', config)
				run(args)
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
