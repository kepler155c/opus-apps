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

while true do
  local target = findTargets()
  if target then
print('looking at ' .. target.name)
    ni.lookAt(target)
    os.sleep(0)
  else
    os.sleep(3)
  end
end
