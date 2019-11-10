local ccemux     = _G.ccemux
local fs         = _G.fs
local peripheral = _G.peripheral

if ccemux then
	-- add a System setup tab
	fs.mount('sys/apps/system/ccemux.lua', 'linkfs', 'packages/ccemux/system/ccemux.lua')

	local Config = require('opus.config')

	for k,v in pairs(Config.load('ccemux')) do
		if not peripheral.getType(k) then
			ccemux.attach(k, v.type, v.args)
		end
	end
end
