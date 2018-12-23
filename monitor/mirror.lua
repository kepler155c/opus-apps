local Terminal = require('terminal')
local Util     = require('util')

local shell = _ENV.shell
local term  = _G.term

local options = {
	scale       = { arg = 's', type = 'flag', value = false,
								 desc = 'Set monitor to .5 text scaling' },
	resize      = { arg = 'r', type = 'flag', value = false,
								 desc = 'Resize terminal to monitor size' },
	execute     = { arg = 'e', type = 'string',
								 desc = 'Execute a program' },
	monitor     = { arg = 'm', type = 'string', value = 'monitor',
								 desc = 'Name of monitor' },
	help        = { arg = 'h', type = 'flag',   value = false,
								 desc = 'Displays the options' },
}

local args = { ... }
if not Util.getOptions(options, args) then
	return
end

local mon = _G.device[options.monitor.value]
if not mon then
	error('mirror: Invalid device')
end

mon.clear()

if options.scale.value then
	mon.setTextScale(.5)
end
mon.setCursorPos(1, 1)

local oterm = Terminal.copy(term.current())
Terminal.mirror(term.current(), mon)

if options.resize.value then
	term.current().getSize = mon.getSize
end

if options.execute.value then
	-- TODO: allow args to be passed
	shell.run(options.execute.value) -- unpack(args))
	Terminal.copy(oterm, term.current())

	mon.setCursorBlink(false)
end
