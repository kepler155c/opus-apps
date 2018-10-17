_G.requireInjector(_ENV)

local Config = require('config')
local Util   = require('util')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local config = {
  max_cows = 15,
}
Config.load('cows', config)

local sensor = device['plethora:sensor'] or
  turtle.equip('right', 'plethora:module:3') and device['plethora:sensor'] or
  error('Plethora sensor required')

local function getCowCount()
  local blocks = sensor.sense()

  Util.filterInplace(blocks, function(v)
    if v.name == 'Cow' then
      return v.y > -.5
    end
  end)

  return #blocks
end

local function butcher()
  turtle.equip('right', 'minecraft:diamond_sword')
  turtle.select(1)

  turtle.attack()
  for _ = 1, 3 do
    turtle.turnRight()
    turtle.attack()
  end
  turtle.equip('right', 'plethora:module:3')

  turtle.dropUp('minecraft:beef')
  turtle.dropUp('minecraft:leather')
end

local function breed()
  turtle.select(1)

  turtle.place('minecraft:wheat')
  for _ = 1, 3 do
    turtle.turnRight()
    turtle.place('minecraft:wheat')
  end
end

turtle.run(function()
  repeat
    if getCowCount() > config.max_cows then
      turtle.setStatus('Butchering')
      butcher()
    elseif turtle.getItemCount('minecraft:wheat') == 0 then
      turtle.setStatus('Out of wheat')
    else
      turtle.setStatus('Breeding')
      breed()
    end
    os.sleep(5)
  until turtle.isAborted()
end)
