_G.requireInjector(_ENV)

local Point = require('point')
local Util = require('util')

local scanner = device['plethora:scanner']

local function scan()
  local blocks = scanner.scan()
  Util.filterInplace(blocks, function(v)
    return v.name == 'minecraft:wheat' and
      scanner.getBlockMeta(v.x, v.y, v.z).metadata == 7
    end)
  
  return blocks
end

local function harvest(blocks)
  Point.eachClosest(turtle.point, blocks, function(b)
    Util.print(b)
    turtle.goto(Point.above(b))
    turtle.digDown()
    turtle.placeDown('minecraft:wheat_seeds')
  end)
end

turtle.reset()
local directions = {     [5] = 2,     [3] = 3,    [4] = 0,    [2] = 1,   }
turtle.placeUp('minecraft:chest')
local _, bi = turtle.inspectUp()
turtle.digUp()
turtle.point.heading = directions[bi.metadata]

while true do
  local blocks = scan()
  harvest(blocks)
  os.sleep(10)
end