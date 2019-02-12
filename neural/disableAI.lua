local device = _G.device

if not device.neuralInterface then
  error('Missing neural interface')
elseif not device.neuralInterface.disableAI then
  _G.printError('Unable to disable AI')
else
  device.neuralInterface.disableAI()
end
