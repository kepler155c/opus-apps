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

local device  = _G.device
local fs      = _G.fs
local kernel  = _G.kernel
local shell   = _ENV.shell
local window  = _G.window

local config = Config.load('nwm', { session = { } })

-- TODO: figure out how to better support scaling
local scale = .5
local xs, ys = 6 * scale, 9 * scale
local dragging
local canvas = device['plethora:glasses'].canvas()
local cw, ch = canvas.getSize()
local opacity = 127

local multishell = Util.shallowCopy(_ENV.multishell)
_ENV.multishell = multishell

cw, ch = cw / xs, ch / ys

local events = {
	glasses_click = 'mouse_click',
	glasses_up = 'mouse_up',
	glasses_drag = 'mouse_drag',
	glasses_scroll = 'mouse_scroll',
}

local function hook(e, eventData)
	local current = kernel.getFocused()
	local x = math.floor(eventData[2] / xs)
	local y = math.floor(eventData[3] / ys)
	local clicked

	if dragging then
		if e == 'glasses_up' then
			dragging = nil
		elseif e == 'glasses_drag' then
			local dx = x - dragging.ax
			local dy = y - dragging.ay
			dragging.tab.gwindow.move(dragging.wx + dx, dragging.wy + dy)
			dragging.tab.titleBar.move(dragging.wx + dx, dragging.wy + dy - 1)

			dragging.tab.wmargs.x = dragging.wx + dx
			dragging.tab.wmargs.y = dragging.wy + dy
			Config.update('nwm', config)
		end
		return
	end

	for _,tab in ipairs(kernel.routines) do
		if tab.gwindow then
			local wx, wy = tab.gwindow.getPosition()
			local ww, wh = tab.gwindow.getSize()

			if x >= wx and x <= wx + ww and y > wy and y < wy + wh then
				clicked = tab
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

	if clicked then
		if clicked ~= current then
			clicked.gwindow.raise()
			kernel.raise(clicked.uid)
		end

		kernel.event(events[e], {
			eventData[1], x, y, clicked.gwindow.side,
		})

	end
	return true
end

function multishell.openTab(env, tab)
	if not tab.wmargs then
		tab.wmargs = {
			x = math.random(1, cw - 51 + 1),
			y = math.random(1, ch - 19 + 1),
			width = 51,
			height = 19,
			opacity = opacity,
			path = tab.path,
			args = tab.args,
		}
		table.insert(config.session, tab.wmargs)
		Config.update('nwm', config)
	else
		tab.path = tab.wmargs.path
		tab.args = tab.wmargs.args
	end

	if tab.path ~= 'sys/apps/shell.lua' then
		if tab.args and #tab.args > 0 then
			tab.args = { tab.path .. ' ' .. table.concat(tab.args or { }, ' ') }
		else
			tab.args = { tab.path }
		end
		tab.path = 'sys/apps/shell.lua'
	end

	local wmargs = tab.wmargs

	local titleBar = Glasses.create({
		x = wmargs.x,
		y = wmargs.y - 1,
		height = 1,
		width = wmargs.width,
		opacity = wmargs.opacity,
	})
	titleBar.canvas:clear('yellow')
	titleBar.canvas:write(1, 1, ' ' .. fs.getName(tab.path), nil, 'black')
	titleBar.canvas:write(wmargs.width - 2, 1, ' x ', nil, 'black')
	titleBar.redraw()

	if not tab.title and tab.path then
		tab.title = fs.getName(tab.path):match('([^%.]+)')
	end
	tab.hidden = true
	tab.title = tab.title or 'untitled'

	local w, h = device.terminal.getSize()
	tab.window = window.create(device.terminal, 1, 2, w, h - 1, false)
	tab.gwindow = Glasses.create(wmargs)
	tab.terminal = tab.gwindow
	tab.titleBar = titleBar
	tab.onExit = tab.onExit or function(self)
		Util.removeByValue(config.session, tab.wmargs)
		Config.update('nwm', config)
		self.gwindow.destroy()
		self.titleBar.destroy()
	end

	local routine, message = kernel.run(env, tab)
	return routine and routine.uid, message
end

function multishell.setTitle(tabId, title)
	local tab = kernel.find(tabId)
	if tab then
		tab.title = title
		tab.titleBar.canvas:clear('yellow')
		tab.titleBar.canvas:write(1, 1, ' ' .. title, nil, 'black')
		tab.titleBar.canvas:write(tab.wmargs.width - 2, 1, ' x ', nil, 'black')
		tab.titleBar.redraw()
	end
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
			eventHandler = function(self, event)
				if event.type == 'slider_update' then
					opacity = event.value
				end
				return UI.Slider.eventHandler(self, event)
			end,
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
			words[1] = shell.resolveProgram(words[1])
			if not words[1] then
				self.notification:error('Invalid program')
			else
				opts.path = 'sys/apps/shell.lua'
				opts.args = table.concat(words, ' ')
				table.insert(config.session, opts)
				Config.update('nwm', config)
				multishell.openTab(_ENV, { wmargs = opts })
				self.notification:success('Started program')
			end

		elseif event.type == 'form_cancel' then
			UI:quit()
		end
		return UI.Page.eventHandler(self, event)
	end,
})

local hookEvents = Util.keys(events)
kernel.hook(hookEvents, hook)

for _,v in pairs(config.session) do
	multishell.openTab(_ENV, { wmargs = v })
end

UI:start()

kernel.unhook(hookEvents, hook)
