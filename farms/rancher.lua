_G.requireInjector(_ENV)

local Adapter    = require('chestAdapter18')
local Config     = require('config')
local Peripheral = require('peripheral')
local Util       = require('util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/rancher.lua'

local retain = Util.transpose {
  'minecraft:shears',
  'minecraft:wheat',
  'minecraft:diamond_sword',
  'plethora:module:3',
}
local config = {
  animal = 'Cow',
  max_animals = 15,
}
Config.load('rancher', config)

local ANIMALS = {
  Pig   = { min =  0, food = 'minecraft:carrot' },
  Sheep = { min = .5, food = 'minecraft:wheat'  },
  Cow   = { min = .5, food = 'minecraft:wheat'  },
}

local animal = ANIMALS[config.animal]

local function equip(side, item, rawName)
  local equipped = Peripheral.lookup('side/' .. side)

  if equipped and equipped.type == item then
    return true
  end

  if not turtle.equip(side, rawName or item) then
    if not turtle.selectSlotWithQuantity(0) then
      error('No slots available')
    end
    turtle.equip(side)
    if not turtle.equip(side, item) then
      error('Unable to equip ' .. item)
    end
  end

  turtle.select(1)
end

local function getLocalName()
  if not device.wired_modem then
    error('wired modem or chest not found')
  end
  return device.wired_modem.getNameLocal()
end

equip('left', 'minecraft:diamond_sword')
equip('right', 'plethora:sensor', 'plethora:module:3')

local sensor = device['plethora:sensor']
local c = Peripheral.lookup('type/minecraft:chest') or error('Missing chest')

local directions = { top = 'down', bottom = 'up' }
local direction = directions[c.side] or getLocalName()
local chest = Adapter({ side = c.side, direction = direction }) or error('missing chest')

if not fs.exists(STARTUP_FILE) then
  Util.writeFile(STARTUP_FILE,
    [[os.sleep(1)
shell.openForegroundTab('rancher.lua')]])
  print('Autorun program created: ' .. STARTUP_FILE)
end

local dispenser = Peripheral.lookup('type/minecraft:dispenser')
local integrator = Peripheral.lookup('type/redstone_integrator')

local function pulse()
  integrator.setOutput('north', true)
  os.sleep(.25)
  integrator.setOutput('north', false)
end

local function turnOffWater()
  if dispenser then
    local list = dispenser.list()
    if list[1].name == 'minecraft:bucket' then
      pulse()
      os.sleep(2)
    end
  end
end

local function turnOnWater()
  if dispenser then
    if dispenser.list()[1].name == 'minecraft:water_bucket' then
      pulse()
    end
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
      chest:insert(slot.index, 64)
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

local s, m = turtle.run(function()
  turnOffWater()

  repeat
    local animalCount, xpCount = getAnimalCount()
    if animalCount > config.max_animals then
      turtle.setStatus('Butchering')
      butcher()
    elseif turtle.getItemCount(animal.food) == 0 then
      if chest:provide({ name = animal.food, damage = 0 }, 64) == 0 then
        print('Out of ' .. animal.food)
        turtle.setStatus('Out of food')
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
