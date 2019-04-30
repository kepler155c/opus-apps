local Point = require('point')
local Sound  = require('sound')
local Util  = require('util')

local device = _G.device
local os     = _G.os

local scanner = device['plethora:scanner']
local sensor  = device['plethora:sensor']

local id = sensor.getID()

local function dropOff()
  local blocks = scanner.scan()
  local b = Util.find(blocks, 'name', 'minecraft:hopper')
  print(not not b)
  if b then
    print('walking ', b.x, b.y + 1, b.z)
    os.sleep(1)
    sensor.walk(b.x, b.y + 1, b.z)
    os.sleep(2)
    repeat until not sensor.isWalking()
    print('done walking')

    blocks = scanner.scan()
    b = Util.find(blocks, 'name', 'minecraft:hopper')
    if b then
      print(b.x, b.z)
    end
    if b and math.abs(b.x) < 1 and math.abs(b.z) < 1 then
      print('dropped')
      sensor.getEquipment().drop(1)
      sensor.getEquipment().drop(2)
      os.sleep(1)
    end
  end
end

while true do
  local sensed = Util.reduce(sensor.sense(), function(acc, s)
    s.y = Util.round(s.y)

    if s.y == 0 and s.name == 'Item' then
      --s.x = Util.round(s.x)
      --s.z = Util.round(s.z)
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
    b = sensor.getMetaByID(b.id)
    if b then
      print('picking up ', b.x, b.y, b.z)
      sensor.walk(b.x, b.y, b.z)
      os.sleep(2)
      repeat until not sensor.isWalking()
      print('done goto')
      os.sleep(.5)
      pt = b
      local amount = sensor.getEquipment().suck(1)
      print('sucked: ' .. amount)
      if amount == 0 then
        amount = sensor.getEquipment().suck(2)
        if amount == 0 then
          print('dropping')
          dropOff()
          break
        end
      end
      Sound.play('entity.item.pickup')
    end
  end

  os.sleep(5)
end

