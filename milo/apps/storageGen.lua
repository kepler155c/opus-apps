--[[
	For initially setting up large amounts of storage chests.
]]

local Util = require('opus.util')

local peripheral = _G.peripheral

local args = { ... }
local st = args[1] or error('Specify a storage type (ie. minecraft:chest)')

local config = { }
peripheral.find(st, function(n)
	config[n] = {
		name = n,
		category = 'storage',
		mtype = 'storage',
	}
end)

print('Found ' .. Util.size(config))

if Util.size(config) == 0 then
	error('Invalid peripheral type')
end

Util.writeTable('usr/config/storageGen', config)
print('storageGen file created in usr/config')
print('update /usr/config/storage with contents (or rename to storage)')
