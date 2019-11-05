local Config = require('opus.config')
local Util   = require('opus.util')

local config = Config.load('lzwfs', {
    enabled = false,
    installed = false,
	filters = {
		'/packages',
		'/sys',
		'/usr/config',
	}
})

if not config.installed then
    -- insert lzwfs into boot startup
    local boot = Util.readTable('.startup.boot')
    table.insert(boot.preload, 1, '/packages/lzwfs/startup.lua')
    Util.writeTable('.startup.boot', boot)

    -- update config
    config.installed = true
    Config.update('lzwfs', config)

    print('Installing lzwfs - rebooting in 3 seconds')
    os.sleep(3)
    os.reboot()
end
