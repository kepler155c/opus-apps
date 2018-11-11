_G.requireInjector(_ENV)

local Config = require('config')
local Util   = require('util')
local InventoryAdapter = require('chestAdapter18')
local Peripheral = require('peripheral')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local retain = Util.transpose {
  'minecraft:shears',
  'minecraft_wheat',
  'minecraft:diamond_sword',
  'plethora:module:3',
}
local config = {
  animal = 'Cow',
  max_animals = 15,
}
Config.load('rancher', config)

local sensor = device['plethora:sensor'] or
  turtle.equip('right', 'plethora:module:3') and device['plethora:sensor'] or
  error('Plethora sensor required')

local dispenser = Peripheral.lookup('type/minecraft:dispenser') or
  error('Dispenser not found')
local integrator = Peripheral.lookup('type/redstone_integrator') or
  error('Integrator not found')

local function pulse()
  integrator.setOutput('north', true)
  os.sleep(.25)
  integrator.setOutput('north', false)
end

local function turnOffWater()
  local list = dispenser.list()
  if list[1].name == 'minecraft:bucket' then
    pulse()
    os.sleep(2)
  end
end

local function turnOnWater()
  if dispenser.list()[1].name == 'minecraft:water_bucket' then
    pulse()
  end
end

local function getAnimalCount()
  local blocks = sensor.sense()

  local grown = 0
  local babies = 0
  local xpCount = 0

  Util.filterInplace(blocks, function(v)
    if v.name == config.animal then
      if v.y > -.5 then grown  = grown  + 1 end
      if v.y < -.5 then babies = babies + 1 end
      return v.y > -.5
    elseif v.name == 'XPOrb' then
      xpCount = xpCount + 1
    end
  end)

  Util.print('%d grown, %d babies, %d xp', grown, babies, xpCount)

  return #blocks, xpCount
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

  turtle.eachFilledSlot(function(slot)
    if not retain[slot.name] then
      turtle.select(slot.index)
      turtle.dropUp()
    end
  end)
end

local function breed()
  turtle.select(1)

  if config.animal == 'Sheep' then
    turtle.place('minecraft:shears')
  end
  turtle.place('minecraft:wheat')
  for _ = 1, 3 do
    turtle.turnRight()
    if config.animal == 'Sheep' then
      turtle.place('minecraft:shears')
    end
    turtle.place('minecraft:wheat')
  end
end

local chest = InventoryAdapter({ side = 'top', direction = 'down' }) or
    error('missing chest above')

local s, m = turtle.run(function()
  turnOffWater()

  repeat
    local animalCount, xpCount = getAnimalCount()
    if animalCount > config.max_animals then
      turtle.setStatus('Butchering')
      butcher()
    elseif turtle.getItemCount('minecraft:wheat') == 0 then
      if chest:provide({ name = 'minecraft:wheat' }, 64) == 0 then
        turtle.setStatus('Out of wheat')
      end
    else
      turtle.setStatus('Breeding')
      breed()
    end
    if xpCount > 2 then
      turnOnWater()
      os.sleep(8)
      turnOffWater()
    end
    os.sleep(5)
  until turtle.isAborted()
end)

if not s and m then
  error(m)
end