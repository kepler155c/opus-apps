
local mon = device.monitor_1
mon.clear()
mon.setTextScale(.5)
_G.requireInjector(_ENV)

local Util = require('util')

mon.setCursorPos(1, 1)

local oldDebug = _G.debug

_G.debug = function(...)
  local oldTerm = term.redirect(mon)
  Util.print(...)
  term.redirect(oldTerm)
end
 
pcall(read)
_G.debug = oldDebug
