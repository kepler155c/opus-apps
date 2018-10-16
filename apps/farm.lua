_G.requireInjector(_ENV)

local Point = require('point')
local Util  = require('util')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local scanner = device['plethora:scanner'] or
  turtle.equip('right', 'plethora:module:2') or
  error('Plethora scanner required')

local crops = {
  ['minecraft:wheat'] =
    { seed = 'minecraft:wheat_seeds', mature = 7 },
  ['minecraft:carrots'] =
    { seed = 'minecraft:carrot', mature = 7 },
  ['minecraft:potatoes'] =
    { seed = 'minecraft:potato', mature = 7 },
  ['minecraft:beetroots'] =
    { seed = 'minecraft:beetroot_seeds', mature = 3 },
}

local function scan()
  local blocks = scanner.scan()
  Util.filterInplace(blocks, function(v)
    if v.name == 'minecraft:reeds' then
      return v.y == 0
    end
    return crops[v.name] and
      scanner.getBlockMeta(v.x, v.y, v.z).metadata == crops[v.name].mature
    end)

  return blocks
end

local function harvest(blocks)
  turtle.equip('right', 'minecraft:diamond_pickaxe')

  Point.eachClosest(turtle.point, blocks, function(b)
    Util.print(b)
    if b.name == 'minecraft:reeds' then
      turtle._goto(b)
    else
      turtle._goto(Point.above(b))
      turtle.digDown()
      turtle.placeDown(crops[b.name].seed)
      turtle.select(1)
    end
  end)

  turtle.equip('right', 'plethora:module:2')
end

turtle.reset()
local facing = scanner.getBlockMeta(0, 0, 0).state.facing
turtle.point.heading = Point.facings[facing].heading

turtle.setPolicy('digOnly')

while true do
  print('scanning')
  local blocks = scan()
  turtle.setPoint({ x = 0, y = 0, z = 0, heading = turtle.point.heading })
  harvest(blocks)
  print('sleeping')
  os.sleep(10)
end
