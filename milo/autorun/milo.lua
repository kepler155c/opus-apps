local device = _G.device
local shell  = _ENV.shell

if device.workbench then
	shell.openForegroundTab('Milo')
elseif device.neuralInterface then
	shell.openForegroundTab('MiloRemote')
end
