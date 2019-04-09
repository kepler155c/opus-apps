local device = _G.device
local os     = _G.os

local function Syntax(missing)
  print([[Required: Neural Interface containing:
 * Kinetic augment
 * Entity sensor
 * Introspection module]])
 error('Missing: ' .. missing)
end

local kinetic = device['plethora:kinetic'] or Syntax('kinetic augment')
local sensor = device['plethora:sensor'] or Syntax('entity sensor')
if not sensor.getMetaOwner then Syntax('introspection module') end

local depth = -3

while true do
  local meta = sensor.getMetaByName('unknown')
  if not meta then
    local owner = sensor.getMetaOwner()
    local held = owner.heldItem and owner.heldItem.getMetadata()
    if held and held.rawName == 'item.fishingRod' then
      kinetic.use(.2)
      print('casting')
      os.sleep(.5)
      meta = sensor.getMetaByName('unknown')
      depth = meta and meta.y - .5 or depth
    else
      print('waiting for fishing rod to be selected')
    end
    os.sleep(1)
  else
    if meta.y < depth then
      kinetic.use(.3)
      print('reeled in')
    end
    os.sleep(.1)
  end
end