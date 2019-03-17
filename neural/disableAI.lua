local device = _G.device

local kinetic = device['plethora:kinetic'] or
  error('Missing kinetic augment')

if not kinetic.disableAI then
  error('Nope')
end

kinetic.disableAI()
