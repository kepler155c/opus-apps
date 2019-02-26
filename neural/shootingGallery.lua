local Mobs  = require('neural.mobs')
local ni    = require('neural.interface')
local Point = require('point')

local os = _G.os

if not ni.look then
  error('neuralInterface required')
end

local uid = ni.getID and ni.getID() or error('Introspection module is required')

local function findTargets()
  local pos = { x = 0, y = 0, z = 0 }
  local l = ni.sense()
  table.sort(l, function(e1, e2)
    return Point.distance(e1, pos) < Point.distance(e2, pos)
  end)

  local targets = { }
  for _,v in ipairs(l) do
    if v.id ~= uid and Mobs.getNames()[v.name] then
      if math.abs(v.y) < 2 then -- pitch is broken
        table.insert(targets, v)
      end
    end
  end
  return #targets > 0 and targets
end

print('Targets:')
for _,v in pairs(ni.sense()) do
  print(v.name)
end

while true do
  local targets = findTargets()
  if targets then
    for _, entity in ipairs(targets) do
      ni.shootAt(entity, 1)
    end
  end
  os.sleep(.5)
end
