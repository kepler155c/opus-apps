local Terminal = require('opus.terminal')
local Util     = require('opus.util')

local device   = _G.device
local os       = _G.os
local parallel = _G.parallel
local shell    = _ENV.shell
local term     = _G.term

-- Example usage: mirror -r -e "vnc 1"

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

local mon
for k,v in pairs(device) do
	if k == options.monitor.value or v.side == options.monitor.value then
		mon = v
		break
	end
end

if not mon then
	error('mirror: Invalid device')
end

mon.clear()

mon.setTextScale(options.scale.value and .5 or 1)
mon.setCursorPos(1, 1)

local oterm = term.current()

if options.resize.value then
	oterm.reposition(1, 1, mon.getSize())
end

local mirror = Terminal.mirror(term.current(), mon)

term.redirect(mirror)

if options.execute.value then
	parallel.waitForAny(
		function()
			shell.run(options.execute.value)
		end,

		function()
			while true do
				local event, side, x, y = os.pullEventRaw('monitor_touch')

				if event == 'monitor_touch' and side == mon.side then
					os.queueEvent('mouse_click', 1, x, y + 1)
					os.queueEvent('mouse_up',    1, x, y + 1)
				end
			end
		end
	)

	term.redirect(oterm)

	mon.setCursorBlink(false)
end
