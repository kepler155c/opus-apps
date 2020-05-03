local Terminal = require('opus.terminal')

local colors = _G.colors
local device = _G.device

--[[
	Create a device for glasses
	Usable as a redirect or UI target

	Example usage:
		Files --display=glasses
		debugMonitor glasses

	In a program:
		local prev = term.redirect(device.glasses)
		shell.run('shell')
		term.redirect(prev)

	Glasses do not use the CC font - so extended chars
	do not display correctly.
]]

-- configurable
local w, h = 46, 19
local scale = .5

local glasses = device['plethora:glasses']
local canvas = glasses.canvas()
local _, cy = 1, 1
local _, gh = canvas:getSize()
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
	['f'] = 0x191919FF, -- transparent
}

local xs, ys = 6 * scale, 9 * scale

-- Position bottom left
local group = canvas.addGroup({ x = 1, y = gh - (h * ys) - 10 })

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

device.glasses = Terminal.window({
	getSize = function()
		return w, h
	end,
	isColor = function()
		return true
	end,
	clear = function()
		--canvas.clear()
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
		-- full lines are always blit
		cy = y
	end,
	setBackgroundColor = function()
	end,
	setTextColor = function()
	end,
	setCursorBlink = function()
	end,
	getBackgroundColor = function()
		return colors.black
	end,
	getTextColor = function()
		return colors.white
	end,
}, 1, 1, w, h, true)

function device.glasses.setTextScale() end

device.glasses.side = 'glasses'
device.glasses.type = 'glasses'
device.glasses.name = 'glasses'
