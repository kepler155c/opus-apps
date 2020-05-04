--[[
	Create a terminal compatible window for glasses canvas.
]]

local Terminal = require('opus.terminal')

local colors     = _G.colors
local device     = _G.device

local scale = .5
local xs, ys = 6 * scale, 9 * scale

local Glasses = { }

function Glasses.create(name, sx, sy, w, h)
	w, h = w or 46, h or 19
	sx, sy = sx or 1, sy or 20

	local glasses = device['plethora:glasses']
	local canvas = glasses.canvas()
	local _, cy = 1, 1
	local lines = { }
	local map = {
		['0'] = 0xF0F0F0FF,
		['1'] = 0xF2B233FF,
		['2'] = 0xE57FD8FF,
		['3'] = 0x99B2F2FF,
		['4'] = 0xDEDE6CFF,
		['5'] = 0x7FCC19FF,
		['6'] = 0xF2B2CCFF,
		['7'] = 0x4C4C4CFF,
		['8'] = 0x999999FF,
		['9'] = 0x4C99B2FF,
		['a'] = 0xB266E5FF,
		['b'] = 0x3366CCFF,
		['c'] = 0x7F664CFF,
		['d'] = 0x57A64EFF,
		['e'] = 0xCC4C4CFF,
		['f'] = 0x191919FF,
	}

	-- Position bottom left
	local pos = { x = sx * xs, y = sy * ys }

	local function init(group)
		for y = 1, h do
			lines[y] = {
				text = { },
				bg = { }
			}
			for x = 1, w do
				lines[y].bg[x] = group.addRectangle(x * xs, y * ys, xs, ys, 0xF0F0F04F)
				lines[y].text[x] = group.addText({ x * xs, y * ys }, '', 0x7FCC19FF)
				lines[y].text[x].setScale(scale)
			end
		end
	end

	local group = canvas.addGroup(pos)
	init(group)

	local gterm = Terminal.window({
		getSize = function()
			return w, h
		end,
		isColor = function()
			return true
		end,
		clear = function()
			for y = 1, h do
				for x = 1, w do
					local ln = lines[y]
					ln.bg[x].setColor(0xF0F0F04F)
					ln.text[x].setText('')
				end
			end
		end,
		blit = function(text, fg, bg)
			for x = 1, #text do
				local ln = lines[cy]
				ln.bg[x].setColor(map[bg:sub(x, x)])
				ln.text[x].setColor(map[fg:sub(x, x)])
				ln.text[x].setText(text:sub(x, x))
			end
		end,
		setCursorPos = function(_, y)
			cy = y -- full lines are always blit
		end,
		getTextColor = function()
			return colors.white
		end,
		setTextColor = function() end,
		getBackgroundColor = function()
			return colors.black
		end,
		setBackgroundColor = function() end,
		setCursorBlink = function() end,
	}, 1, 1, w, h, true)

	function gterm.setTextScale() end
	function gterm.getPosition() return sx, sy end
	function gterm.setVisible() end
	function gterm.raise()
		local g = canvas.addGroup(pos)
		init(g)
		gterm.redraw()
		group.remove()
		group = g
	end
	function gterm.destroy()
		group.remove()
	end

	gterm.name = name
	gterm.side = name
	gterm.type = 'glasses'

	return gterm
end

return Glasses
