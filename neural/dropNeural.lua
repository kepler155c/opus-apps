local peripheral = _G.peripheral

local ni = peripheral.find('neuralInterface')
if not ni then
  error('Missing neural interface')
elseif not ni.getEquipment then
  error('Missing introspection module')
else
  ni.getEquipment().drop(6)
end
