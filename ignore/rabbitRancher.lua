--[[
  Breed rabbits with a rabbit.
]]

local neural  = require('neural.interface')
local Point   = require('point')
local Sound   = require('sound')
local Util    = require('util')

local os = _G.os

local BREEDING  = 'Rabbit'
local WALK_SPEED  = 1.3
local MAX_GROWN   = 100
local BREED_DELAY = 120

neural.assertModules({
  'plethora:sensor',
  'plethora:scanner',
  'plethora:laser',
  'plethora:kinetic',
  'plethora:introspection',
})

local ID = neural.getID()
local fed = { }

local function resupply()
  local slot = neural.getEquipment().list()[1]
  if slot and slot.count > 32 then
    return
  end
  print('resupplying')

  local dispenser = Util.find(neural.scan(), 'name', 'minecraft:wooden_pressure_plate')
  if dispenser then
    if math.abs(dispenser.x) > 1 or math.abs(dispenser.z) > 1 then
      neural.walkTo({ x = dispenser.x, y = 0, z = dispenser.z }, WALK_SPEED)
    end
    neural.lookAt(dispenser)
    neural.getEquipment().suck(1, 64)
  end
end

local function breed(entity)
  print('breeding')
  entity.lastFed = os.clock()
  fed[entity.id] = entity

  neural.walkTo(entity, WALK_SPEED, .5)
  entity = neural.getMetaByID(entity.id)
  if entity and not entity.isChild then
    neural.lookAt(entity)
    neural.use(1)
    os.sleep(.1)
  end
end

local function kill(entity)
  print('killing')
  neural.walkTo(entity, WALK_SPEED, 2)
  entity = neural.getMetaByID(entity.id)
  if entity and not entity.isChild then
    neural.lookAt(entity)
    neural.fireAt({ x = entity.x, y = 0, z = entity.z })
    Sound.play('entity.firework.launch')
    os.sleep(.2)
  end
end

local function getEntities()
  return Util.filter(neural.sense(), function(entity)
    if entity.name == BREEDING and entity.y > -.5 and entity.id ~= ID then
      return true
    end
  end)
end

local function getHungry(entities)
  for _,v in pairs(entities) do
    if not fed[v.id] or
       os.clock() - fed[v.id].lastFed > BREED_DELAY then
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

local function dropOff()
  print('dropping')

  if neural.getEquipment().list()[2] then
    local b = Util.find(neural.scan(), 'name', 'minecraft:hopper')
    if b then
      neural.walkTo({ x = b.x, y = 0, z = b.z }, 2)

      b = Util.find(neural.scan(), 'name', 'minecraft:hopper')
      if b and math.abs(b.x) < 1 and math.abs(b.z) < 1 then
        print('dropped')
        neural.getEquipment().drop(2)
      end
    end
  end
end

local function pickup(id)
  local b = neural.getMetaByID(id)
  if b then
    neural.walkTo(b, 2)

    local main = neural.getEquipment().list()[1]
    local amount = neural.getEquipment().suck(not main and 2 or nil)
    print('sucked: ' .. amount)
    if amount > 0 then
      Sound.play('entity.item.pickup')
      return true
    end
  end
end

local function drops()
  local sensed = Util.reduce(neural.sense(), function(acc, s)
    if Util.round(s.y) == 0 and s.name == 'Item' then
      acc[s.id] = s
    end
    return acc
  end, { })

  local pt = { x = 0, y = 0, z = 0 }
  while true do
    local b = Point.closest(pt, sensed)
    if not b then
      break
    end
    sensed[b.id] = nil

    if pickup(b.id) then
      pt = b
    else
      dropOff()
      break
    end
  end
end

while true do
  resupply()

  local entities = getEntities()

  if Util.size(entities) > MAX_GROWN then
    kill(randomEntity(entities))
  else
    local entity = getHungry(entities)
    if entity then
      breed(entity)
    else
      print('sleeping')
      os.sleep(5)
    end
    drops()
  end
end