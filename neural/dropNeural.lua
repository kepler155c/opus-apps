local device = _G.device

local intro = device['plethora:introspection'] or
  error('Missing Introspection module')

if intro.getBaubles then
  intro.getBaubles().drop(5)
else
  intro.getEquipment().drop(6)
end
