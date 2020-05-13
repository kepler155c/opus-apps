--[[
	A simplistic window manager for glasses.

	TODO:
	opacity for text/background separately
	support for specifying scale factor
]]

local Config  = require('opus.config')
local Glasses = require('neural.glasses')
local Util    = require('opus.util')

local colors  = _G.colors
local device  = _G.device
local fs      = _G.fs
local kernel  = _G.kernel
local shell   = _ENV.shell
local term    = _G.term
local window  = _G.window

local config = Config.load('nwm', { session = { } })

-- TODO: figure out how to better support scaling
local scale = .5
local xs, ys = 6 * scale, 9 * scale
local dragging, resizing
local canvas = device['plethora:glasses'].canvas()
local cw, ch = canvas.getSize()

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

	if resizing then
		if e == 'glasses_up' then
			resizing.group.remove()
			if resizing.dx then
				resizing.tab.wmargs.x = resizing.dx
				resizing.tab.wmargs.y = resizing.dy
				resizing.tab.wmargs.width = resizing.dw
				resizing.tab.wmargs.height = resizing.dh
				resizing.tab.gwindow.reposition2(resizing.dx, resizing.dy, resizing.dw, resizing.dh)
				resizing.tab:resume('term_resize')

				resizing.tab.titleBar.reposition2(resizing.dx, resizing.dy - 1, resizing.dw, 1)
				resizing.tab.titleBar:draw(resizing.tab.title)
				Config.update('nwm', config)
			end
			resizing = nil

		elseif e == 'glasses_drag' then
			local dx = x - resizing.ax
			local dy = y - resizing.ay

			resizing.dx = resizing.tab.wmargs.x
			resizing.dy = math.min(resizing.tab.wmargs.y + dy, resizing.tab.wmargs.y + resizing.tab.wmargs.height - 4)
			resizing.dw = math.max(resizing.tab.wmargs.width + dx, 8)
			resizing.dh = math.max(resizing.tab.wmargs.height - dy, 4)

			resizing.group.setPosition((resizing.dx + 1) * xs, resizing.dy * ys)
			resizing.group.setSize(resizing.dw * xs, (resizing.dh + 1) * ys)
		end
		return
	end

	for _,tab in ipairs(kernel.routines) do
		if tab.gwindow then
			local wx, wy = tab.gwindow.getPosition()
			local ww, wh = tab.gwindow.getSize()

			if x >= wx and x <= wx + ww and y > wy and y <= wy + wh then
				clicked = tab
				x = x - wx
				y = y - wy
				break
			elseif x >= wx and x <= wx + ww and y == wy then
				if e == 'glasses_click' then
					if x == wx + ww - 1 then
						multishell.terminate(tab.uid)
					elseif x == wx + ww - 3 then
						local pos = { x = (tab.wmargs.x + 1) * xs, y = tab.wmargs.y * ys }
						resizing = { tab = tab, ax = x, ay = y }
						resizing.group = canvas.addRectangle(pos.x, pos.y, tab.wmargs.width * xs, (tab.wmargs.height + 1) * ys, 0xF0F0F04F)
					else
						dragging = { tab = tab, ax = x, ay = y, wx = wx, wy = wy }
					end
					return
				elseif e == 'glasses_scroll' then
					tab.wmargs.opacity = Util.clamp(tab.wmargs.opacity - (eventData[1] * 5), 0, 255)
					Config.update('nwm', config)
					tab.gwindow.setOpacity(tab.wmargs.opacity)
				end
			end
		end
	end

	if clicked then
		local current = kernel.getFocused()
		if clicked ~= current then
			clicked.gwindow.raise()
			clicked.titleBar.raise()
			kernel.raise(clicked.uid)
		end

		clicked:resume(events[e], eventData[1], x, y)
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
			opacity = 192,
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

	if not tab.title and tab.path then
		tab.title = fs.getName(tab.path):match('([^%.]+)')
	end
	tab.hidden = true
	tab.title = tab.title or 'untitled'

	local titleBar = Glasses.create({
		x = wmargs.x,
		y = wmargs.y - 1,
		height = 1,
		width = wmargs.width,
		opacity = 160,
	})
	titleBar.routine = tab
	function titleBar:draw(title)
		titleBar.canvas:clear('yellow')
		titleBar.canvas:write(1, 1, ' ' .. title, nil, 'black')
		titleBar.canvas:write(self.routine.wmargs.width - 4, 1, ' + x ', nil, 'black')
		titleBar.redraw()
	end
	titleBar:draw(tab.title)

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
		tab.titleBar:draw(title)
	end
end

local hookEvents = Util.keys(events)
kernel.hook(hookEvents, hook)

for _,v in pairs(config.session) do
	multishell.openTab(_ENV, { wmargs = v })
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
print('Scroll on a titlebar adjusts opacity\n')
print('Run a program')
pcall(function()
	while true do
		_G.write('> ')
		local p = _G.read(nil, nil, shell.complete)
		if p and #Util.trim(p) > 0 then
			multishell.openTab(_ENV, {
				path = 'sys/apps/shell.lua',
				args = { p },
			})
		end
	end
end)

kernel.unhook(hookEvents, hook)
