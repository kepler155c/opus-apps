local Util  = require('opus.util')

local fs    = _G.fs
local read  = _G.read
local shell = _ENV.shell

local CONFIG_FILE = '/usr/config/milo.state'

local config = Util.readTable(CONFIG_FILE) or { }
if not config.plugins then
	config.plugins = { }
end

local dir = fs.getDir(shell.getRunningProgram())

config.plugins[fs.combine(dir, 'shopConfig.lua')] = true
config.plugins[fs.combine(dir, 'shopTab.lua')]    = true
config.plugins[fs.combine(dir, 'shopView.lua')]   = true

Util.writeTable(CONFIG_FILE, config)

print('Plugin Installed')
print('Press enter to exit')
read()
