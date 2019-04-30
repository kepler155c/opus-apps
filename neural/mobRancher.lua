local Kinetic = require('neural.kinetic')
local Sound   = require('sound')
local Util    = require('util')

local device = _G.device
local os     = _G.os

local sensor = device['plethora:sensor']
local scanner = device['plethora:scanner']

local fed = { }

local function resupply()
  local slot = sensor.getEquipment().list()[1]
  if slot and slot.count > 32 then
    return
  end
  print('resupplying')
  for _ = 1, 8 do
    local dispenser = Util.find(scanner.scan(), 'name', 'minecraft:dispenser')
    if dispenser and math.abs(dispenser.x) <= 1 and math.abs(dispenser.z) <= 1 then
        Kinetic.lookAt(dispenser)
        Kinetic.use(0, 'off')
        os.sleep(.2)
        Kinetic.getEquipment().suck(1, 64)
    elseif dispenser then
      Kinetic.walkTo(dispenser)
    end
  end
end

local function feed(entity)
  print('feeding')
  entity.lastFed = os.clock()
  fed[entity.id] = entity

  Kinetic.walkAgainst(entity)
  entity = sensor.getMetaByID(entity.id)
  if entity then
    Kinetic.lookAt(entity)
    Kinetic.use(1)
    os.sleep(.1)
  end
end

local function kill(entity)
  print('killing')
  Kinetic.walkAgainst(entity, 2)
  entity = sensor.getMetaByID(entity.id)
  if entity then
    Kinetic.lookAt(entity)
    Kinetic.fireAt({ x = entity.x, y = 0, z = entity.z })
    Sound.play('entity.firework.launch')
  end
end

local function getEntities()
  return Util.filter(sensor.sense(), function(entity)
    if entity.name == 'Cow' and entity.y > -.5 then
      return true
    end
  end)
end

local function getHungry(entities)
  for _,v in pairs(entities) do
    if not fed[v.id] or os.clock() - fed[v.id].lastFed > 60 then
      return v
    end
  end
end

local function randomEntity(entities)
  local r = math.random(1, Util.size(entities))
  local i = 1
  for _, v in pairs(entities) do
    i = i + 1
    if i > r then
      return v
    end
  end
end

while true do
  resupply()

  local entities = getEntities()

  if Util.size(entities) > 10 then
    kill(randomEntity(entities))
  else
    local entity = getHungry(entities)
    if entity then
      feed(entity)
    else
      os.sleep(5)
    end
  end
end
