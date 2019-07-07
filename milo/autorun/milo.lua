local fs         = _G.fs
local peripheral = _G.peripheral
local shell      = _ENV.shell

if fs.exists('packages/milo/Milo.lua') then
	fs.delete('packages/milo/Milo.lua')
	fs.delete('packages/milo/plugins/listing.lua')
end

fs.delete('packages/milo/apis/milo.lua')
fs.delete('packages/milo/plugins/manipulator.lua')

if peripheral.find('workbench') and shell.openForegroundTab then
	shell.openForegroundTab('MiloLocal')
end
