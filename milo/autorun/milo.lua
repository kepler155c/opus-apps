local device = _G.device
local shell  = _ENV.shell

if device.workbench then
	shell.openForegroundTab('Milo')
end
