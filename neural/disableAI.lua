local peripheral = _G.peripheral

local ni = peripheral.find('neuralInterface')
if not ni then
  error('Missing neural interface')
elseif not ni.disableAI then
  error('Missing kinetic augment')
else
  ni.disableAI()
end
