local Angle = require('neural.angle')
local Util  = require('util')

local device = _G.device
local os     = _G.os

local module = device['plethora:kinetic'] or error('Missing kinetic')

local Kinetic = Util.shallowCopy(module)

function Kinetic.lookAt(pt)
  if pt then
    local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
    return Kinetic.look(yaw, pitch)
  end
end

function Kinetic.fireAt(pt)
  local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
  return Kinetic.fire(yaw, pitch, .5)
end

function Kinetic.walkTo(pt)
  Kinetic.walk(pt.x, 0, pt.z)
  os.sleep(1)
  repeat until not Kinetic.isWalking()
end

function Kinetic.walkAgainst(pt, radius)
  local angle = math.atan2(pt.x, pt.z)
  local x = pt.x - ((radius or .8) * math.sin(angle))
  local z = pt.z - ((radius or .8) * math.cos(angle))

  Kinetic.walk(x, 0, z)
  os.sleep(1)
  repeat until not Kinetic.isWalking()
end

function Kinetic.testWalk()
  local e = Kinetic.getMetaByName('kepler155c')
  Kinetic.walkToEntity(e)
end


return Kinetic
