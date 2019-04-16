local machine = require('neural.statemachine')

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
local w, h

if canvas then
  w, h = canvas.getSize()
  icon = canvas.addItem({ w - 20, h - 20 }, 'minecraft:fishing_rod' )
end

local fsm = machine.create({
  events = {
    { name = 'startup', from = 'none',    to = 'wait' },
    { name = 'rod',     from = 'wait',    to = 'idle' },
    { name = 'norod',   from = 'idle',    to = 'wait' },
    { name = 'norod',   from = 'fishing', to = 'wait' },
    { name = 'cast',    from = 'idle',    to = 'fishing' },
    { name = 'reel',    from = 'fishing', to = 'idle' },
  },

  callbacks = {
    -- events
    oncast = function()
      kinetic.use(.2)
      os.sleep(.5)
      local meta = sensor.getMetaByName('unknown')
      depth = meta and meta.y - .5 or depth
    end,

    onreel =  function()
      kinetic.use(.3)
      os.sleep(.5)
    end,

    -- state changes
    onenterwait = function()
      print('waitng for fishing rod to be selected')
      if icon then
        icon.remove()
        icon = canvas.addItem({ w - 20, h - 20 }, 'minecraft:fishing_rod' )
      end
    end,

    onleavewait = function()
      print('fishing...')
    end,

    onenterfishing = function()
      if icon then
        icon.remove()
        scale = 0
        icon = canvas.addItem({ w - 20, h - 20 }, 'minecraft:fish', math.random(0, 3) )
      end
    end,
  }
})

local function isHoldingRod()
  local owner = sensor.getMetaOwner()
  local held = owner.heldItem and owner.heldItem.getMetadata()
  return held and held.rawName == 'item.fishingRod'
end

local function fish()
  fsm:startup()
  while true do
    local meta = sensor.getMetaByName('unknown')
    if isHoldingRod() then
      fsm:rod()
      if not meta then
        fsm:cast()
      elseif meta.y < depth then
        fsm:reel()
      end
      os.sleep(.1)
    else
      fsm:norod()
      os.sleep(1)
    end

    if icon and fsm.current == 'fishing' then
      scale = scale + 1
      icon.setScale(scales[(scale % #scales) + 1])
    end
  end
end

local s, m = pcall(fish)

if icon then
  icon.remove()
end

if not s and m then
  error(m)
end
