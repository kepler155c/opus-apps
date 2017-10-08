_G.requireInjector()

local Terminal = require('terminal')

local shell = _ENV.shell
local term  = _G.term

local args = { ... }
local mon = _G.device[table.remove(args, 1) or 'monitor']
if not mon then
  error('mirror: Invalid device')
end

mon.clear()
mon.setTextScale(.5)
mon.setCursorPos(1, 1)

local oterm = Terminal.copy(term.current())
Terminal.mirror(term.current(), mon)

term.current().getSize = mon.getSize

if #args > 0 then
  shell.run(unpack(args))
  Terminal.copy(oterm, term.current())

  mon.setCursorBlink(false)
end
