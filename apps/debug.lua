_G.requireInjector(_ENV)

local Util = require('util')

local device = _G.device
local os     = _G.os
local term   = _G.term

local args = { ... }
local mon = device[args[1] or 'monitor'] or error('Syntax: debug <monitor>')

mon.clear()
mon.setTextScale(.5)
mon.setCursorPos(1, 1)

local oldDebug = _G.debug

_G.debug = function(...)
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

_G.debug = oldDebug
