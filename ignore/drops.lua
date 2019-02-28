local Point = require('point')
local Util  = require('util')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local scanner = device['plethora:scanner']
local sensor  = device['plethora:sensor']

turtle.reset()

local facing = scanner.getBlockMeta(0, 0, 0).state.facing
turtle.point.heading = Point.facings[facing].heading

while true do
  local sensed = Util.reduce(sensor.sense(), function(acc, s)
    s.y = Util.round(s.y)
    if s.y == -1 then
      s.x = Util.round(s.x) + turtle.point.x
      s.z = Util.round(s.z) + turtle.point.z
      table.insert(acc, s)
    end
    return acc
  end, { })

  Point.eachClosest(turtle.point, sensed, function(s)
    turtle.suckDownAt(s)
  end)

  os.sleep(5)
end
