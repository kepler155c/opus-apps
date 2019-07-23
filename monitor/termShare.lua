local Util       = require('opus.util')

local device     = _G.device
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term

-- list this terminal in the devices list so it's available via
-- peripheral sharing

local args = Util.parse(...)
local name = args[1] or error('Syntax: termShare [--title=title] term_name')
local title = args.title

device[name] = term.current()
device[name].name = name
device[name].side = name
device[name].type = 'terminal'

if title then
	multishell.setTitle(multishell.getCurrent(), title)
end
os.pullEventRaw('terminate')
os.queueEvent('peripheral_detach', name)
