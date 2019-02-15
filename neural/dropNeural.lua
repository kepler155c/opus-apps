local device = _G.device

if not device.neuralInterface then
  error('Missing neural interface')
elseif not device.neuralInterface.getEquipment then
  error('Missing introspection module')
else
  device.neuralInterface.getEquipment().drop(6)
end
