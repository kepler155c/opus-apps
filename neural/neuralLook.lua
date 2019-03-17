local ni    = require('neural.interface')
local Point = require('point')
local Util  = require('util')

local os = _G.os

local pos = { x = 0, y = 0, z = 0 }
local meta = ni.getMetaOwner()

local function findTargets()
	local l = ni.sense()

  Util.filterInplace(l, function(a)
    return math.abs(a.motionY) > 0 and meta.id ~= a.id
  end)
  table.sort(l, function(e1, e2)
		return Point.distance(e1, pos) < Point.distance(e2, pos)
	end)

  return l[1]
end

local last
local count = 0

while true do
  local target = findTargets()
  if target and (not last or Point.distance(last, target) > .2) then
--      last = target
if last then print(Point.distance(last, target)) end
last = target
--print(target.x, target.y, target.z, count)
      ni.lookAt(target)
      count = 0
      os.sleep(0)
--    elseif count < 10 then
--      count = count + 1
--      os.sleep(.1)
--    end
  else
    count = count + 1
    if count > 50 or not target then
    ni.lookAt({ x = math.random(-10, 10),
                y = math.random(-10, 10),
                z = math.random(-10, 10) })
                os.sleep(3)
    else
      os.sleep(.1)
    end
  end
end
