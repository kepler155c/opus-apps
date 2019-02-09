local device = _G.device
local fs     = _G.fs
local shell  = _ENV.shell

if fs.exists('packages/milo/Milo.lua') then
	fs.delete('packages/milo/Milo.lua')
	fs.delete('packages/milo/plugins/listing.lua')
end

if device.workbench then
	shell.openForegroundTab('MiloLocal')
end
