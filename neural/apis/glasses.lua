--[[
	Create a terminal compatible window for glasses canvas.
]]

local Terminal = require('opus.terminal')
local Util     = require('opus.util')

local colors     = _G.colors
local device     = _G.device

local Glasses = { }

function Glasses.create(args)
	local opts = {
		x = 1, y = 20,
		width = 51, height = 19,
		scale = .5,
		name = 'glasses',
		opacity = 0xff,
	}
	Util.merge(opts, args)

	local xs, ys = 6 * opts.scale, 9 * opts.scale
	local glasses = device['plethora:glasses']
	local canvas = glasses.canvas()
	local _, cy = 1, 1
	local lines = { }
	local map = {
		['0'] = 0xF0F0F000,
		['1'] = 0xF2B23300,
		['2'] = 0xE57FD800,
		['3'] = 0x99B2F200,
		['4'] = 0xDEDE6C00,
		['5'] = 0x7FCC1900,
		['6'] = 0xF2B2CC00,
		['7'] = 0x4C4C4C00,
		['8'] = 0x99999900,
		['9'] = 0x4C99B200,
		['a'] = 0xB266E500,
		['b'] = 0x3366CC00,
		['c'] = 0x7F664C00,
		['d'] = 0x57A64E00,
		['e'] = 0xCC4C4C00,
		['f'] = 0x19191900,
	}

	for k,v in pairs(map) do
		map[k] = v + opts.opacity
	end

	-- Position bottom left
	local pos = { x = opts.x * xs, y = opts.y * ys }

	local function init(group)
		for y = 1, opts.height do
			lines[y] = {
				text = { },
				bg = { }
			}
			for x = 1, opts.width do
				lines[y].bg[x] = group.addRectangle(x * xs, y * ys, xs, ys, 0xF0F0F04F)
				lines[y].text[x] = group.addText({ x * xs, y * ys }, '', 0x7FCC19FF)
				lines[y].text[x].setScale(opts.scale)
			end
		end
	end

	local group = canvas.addGroup(pos)
	init(group)

	local gterm = Terminal.window({
		isColor = function()
			return true
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
		setCursorBlink = function() end,
	}, 1, 1, opts.width, opts.height, true)

	function gterm.setTextScale() end
	function gterm.getPosition() return opts.x, opts.y end
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
	function gterm.getTextScale()
		return opts.scale
	end

	gterm.name = opts.name
	gterm.side = opts.name
	gterm.type = 'glasses'

	return gterm
end

return Glasses
