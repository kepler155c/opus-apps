local Util = require('util')

local os         = _G.os
local peripheral = _G.peripheral
local term       = _G.term

local args = { ... }
local mon = args[1] and peripheral.wrap(args[1]) or
	peripheral.find('monitor') or
	error('Syntax: debug <monitor>')

mon.clear()
mon.setTextScale(.5)
mon.setCursorPos(1, 1)

local oldDebug = _G._debug

_G._debug = function(...)
	local oldTerm = term.redirect(mon)
	Util.print(...)
	term.redirect(oldTerm)
end

repeat
	local e, side = os.pullEventRaw('monitor_touch')
	if e == 'monitor_touch' and side == mon.side then
		mon.clear()
		mon.setTextScale(.5)
		mon.setCursorPos(1, 1)
	end
until e == 'terminate'

_G._debug = oldDebug
