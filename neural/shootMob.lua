_G.requireInjector(_ENV)

local ni = require('neural.interface')
local uid = ni.getID and ni.getID() or error('Introspection module is required')

local os = _G.os

local args = { ... }

local function findEntity(name)
  for _,v in pairs(ni.sense()) do
    if v.id ~= uid and v.name == name then
      return v
    end
  end
end

print('Targets:')
for _,v in pairs(ni.sense()) do
  print(v.name)
end

local target = args[1] or error('specify target name')

repeat
  local entity = findEntity(target)
  if entity then
    ni.shootAt(entity, 1)
  end
  os.sleep(.5)
until not entity
