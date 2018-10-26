_G.requireInjector(_ENV)

local Util = require('util')

local colors = _G.colors
local device = _G.device

local args = { ... }
local mon = device[args[1] or 'monitor'] or error('Syntax: MiloMonitor <monitor>')
local config = Util.readTable('/usr/config/milo') or error('Milo is not configured')

local row
local monWidth, monHeight = mon.getSize()
local machines = { }

local function write(x, y, s, bg, fg)
	mon.setCursorPos(x, y)
	mon.setBackgroundColor(bg)
	if fg then
		mon.setTextColor(fg)
	end
	mon.write(s)
end

local function progress(y, percent)
	local width = math.ceil(percent / 100 * monWidth)
	write(2, y, string.rep(' ', monWidth - 2), colors.gray)
	write(2, y, string.rep(' ', width), colors.lime)
end

local function draw(machine, percent)
	write(2, row, machine.displayName or machine.name, colors.black, colors.yellow)
	progress(row + 1, percent)
	row = row + 3
end

local function redraw()
	row = 1
	mon.setBackgroundColor(colors.black)
	mon.clear()
	for _,machine in ipairs(machines) do
		local dev = device[machine.name]
		if dev then
			local percent = 50
			if machine.mtype == 'storage' then
				percent = Util.size(dev.list()) / dev.size() * 100
			end
			draw(machine, percent)
		end
	end
end

for _, v in pairs(config.remoteDefaults) do
	table.insert(machines, v)
end

table.sort(machines, function(a, b)
	return (a.displayName or a.name) < (b.displayName or b.name)
end)

mon.setTextScale(.5)
redraw()
