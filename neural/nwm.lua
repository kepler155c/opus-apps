--[[
	A simplistic window manager for glasses.

	TODO:
	opacity for text/background separately
	support for specifying scale factor
]]

local Config  = require('opus.config')
local Glasses = require('neural.glasses')
local UI      = require('opus.ui')
local Util    = require('opus.util')

local fs         = _G.fs
local kernel     = _G.kernel
local multishell = _ENV.multishell
local shell      = _ENV.shell

local config = Config.load('nwm', { session = { } })

-- TODO: figure out how to better support scaling
local scale = .5
local xs, ys = 6 * scale, 9 * scale
local dragging

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

	if dragging then
		if e == 'glasses_up' then
			dragging = nil
		elseif e == 'glasses_drag' then
			local dx = x - dragging.ax
			local dy = y - dragging.ay
			dragging.tab.window.move(dragging.wx + dx, dragging.wy + dy)
			dragging.tab.titleBar.move(dragging.wx + dx, dragging.wy + dy - 1)

			dragging.tab.wmargs.x = dragging.wx + dx
			dragging.tab.wmargs.y = dragging.wy + dy
			Config.update('nwm', config)
		end
		return
	end

	for _,tab in ipairs(kernel.routines) do
		if tab.window.type == 'glasses' then
			local wx, wy = tab.window.getPosition()
			local ww, wh = tab.window.getSize()

			if x >= wx and x <= wx + ww and y > wy and y < wy + wh then
				clickedTab = tab
				x = x - wx
				y = y - wy
				break
			elseif e == 'glasses_click' and x >= wx and x <= wx + ww and y == wy then
				if x == wx + ww - 1 then
					multishell.terminate(tab.uid)
				else
					dragging = { tab = tab, ax = x, ay = y, wx = wx, wy = wy }
				end
				return
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

	local titleBar = Glasses.create({
		x = args.x,
		y = args.y - 1,
		height = 1,
		width = args.width,
		opacity = args.opacity,
	})
	titleBar.canvas:clear('yellow')
	titleBar.canvas:write(1, 1, ' ' .. fs.getName(args.path), nil, 'black')
	titleBar.canvas:write(args.width - 2, 1, ' x ', nil, 'black')
	titleBar.redraw()

	multishell.openTab({
		path = args.path,
		args = args.args,
		hidden = true,
		onDestroy = function()
			Util.removeByValue(config.session, args)
			Config.update('nwm', config)
			window.destroy()
			titleBar.destroy()
		end,
		window = window,
		titleBar = titleBar,
		wmargs = args,
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
			labelWidth = 3,
			transform = math.floor,
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

		elseif event.type == 'form_cancel' then
			UI:quit()
		end
		return UI.Page.eventHandler(self, event)
	end,
})

for _,v in pairs(config.session) do
	run(v)
end

UI:start()

kernel.unhook(hookEvents, hook)
