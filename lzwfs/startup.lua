local fs        = _G.fs
local textutils = _G.textutils

local CONFIG = 'usr/config/lzwfs'

local config = { }

if fs.exists(CONFIG) then
    local f = fs.open(CONFIG, 'r')
	if f then
		config = textutils.unserialize(f.readAll())
		f.close()
    end
end

os.run(_ENV, '/packages/lzwfs/lzwfs.lua')
fs.option('compression', 'filters', config.filters)
fs.option('compression', 'enabled', config.enabled)
