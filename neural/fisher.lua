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
local sensor  = device['plethora:sensor'] or Syntax('entity sensor')
local canvas  = device['plethora:glasses'] and device['plethora:glasses'].canvas()

if not sensor.getMetaOwner then Syntax('introspection module') end

local depth = -3
local icon
local scales = { .2, .4, .6, .8, 1, .8, .6, .4 }
local scale = 0

if canvas then
  local w, h = canvas.getSize()
  icon = canvas.addItem({ w - 20, h - 20 }, 'minecraft:fishing_rod' )
end

local function fish()
  while true do
    local meta = sensor.getMetaByName('unknown')
    if not meta then
      local owner = sensor.getMetaOwner()
      local held = owner.heldItem and owner.heldItem.getMetadata()
      if held and held.rawName == 'item.fishingRod' then
        if icon then
          icon.setItem('minecraft:fish', 1)
        end
        kinetic.use(.2)
        print('casting')
        os.sleep(.5)
        meta = sensor.getMetaByName('unknown')
        depth = meta and meta.y - .5 or depth
      else
        if icon then
          icon.setItem('minecraft:fishing_rod')
        end
        print('waiting for fishing rod to be selected')
      end
      scale = 1
      icon.setScale(1)
      os.sleep(1)
    else
      if meta.y < depth then
        kinetic.use(.3)
        print('reeled in')
      end
      if icon then
        scale = scale + 1
        icon.setScale(scales[(scale % #scales) + 1])
      end
      os.sleep(.1)
    end
  end
end

pcall(fish)

if icon then
  icon.remove()
end
