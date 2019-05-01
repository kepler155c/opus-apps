local neural = require('neural.interface')
local Point  = require('point')
local Sound  = require('sound')
local Util   = require('util')

local device = _G.device
local os     = _G.os

local scanner = device['plethora:scanner']
local sensor  = device['plethora:sensor']

local function dropOff()
  print('dropping')

  local blocks = scanner.scan()
  local b = Util.find(blocks, 'name', 'minecraft:hopper')

  if b then
    neural.walkTo({ x = b.x, y = 0, z = b.z })

    blocks = scanner.scan()
    b = Util.find(blocks, 'name', 'minecraft:hopper')
    if b and math.abs(b.x) < 1 and math.abs(b.z) < 1 then
      print('dropped')
      sensor.getEquipment().drop(1)
      sensor.getEquipment().drop(2)
      os.sleep(1)
    end
  end
end

local function pickup(id)
  local b = sensor.getMetaByID(id)
  if b then
    neural.walkTo(b)

    local amount = sensor.getEquipment().suck()
    print('sucked: ' .. amount)
    if amount > 0 then
      Sound.play('entity.item.pickup')
      return true
    end
  end
end

while true do
  local sensed = Util.reduce(sensor.sense(), function(acc, s)
    s.y = Util.round(s.y)
    if s.y == 0 and s.name == 'Item' then
      acc[s.id] = s
    end
    return acc
  end, { })

  local pt = { x = 0, y = 0, z = 0 }
  while true do
    local b = Point.closest(pt, sensed)
    if not b then
      os.sleep(5)
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

