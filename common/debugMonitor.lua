local Util = require('opus.util')

local device     = _G.device
local os         = _G.os
local peripheral = _G.peripheral
local term       = _G.term

local args = { ... }
local mon = not args[1] and term.current() or
	device[args[1]] or
	peripheral.wrap(args[1]) or
	peripheral.find('monitor') or
	error('Syntax: debug <monitor>')

mon.clear()
if mon.setTextScale then
	mon.setTextScale(.5)
end
mon.setCursorPos(1, 1)

local oldDebug = _G._syslog

_G._syslog = function(...)
	local oldTerm = term.redirect(mon)
	Util.print(...)
	term.redirect(oldTerm)
	oldDebug(...)
end

repeat
	local e, side = os.pullEventRaw('monitor_touch')
	if e == 'monitor_touch' and side == mon.side then
		mon.clear()
		if mon.setTextScale then
			mon.setTextScale(.5)
		end
		mon.setCursorPos(1, 1)
	end
until e == 'terminate'

_G._syslog = oldDebug
