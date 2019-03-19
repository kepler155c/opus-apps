local Angle = require('neural.angle')
local Util  = require('util')

local device = _G.device

local module = device['plethora:kinetic'] or error('Missing kinetic')

local Kinetic = Util.shallowCopy(module)

function Kinetic.lookAt(pt)
  --local x = pt.x < 0 and pt.x + .5 or pt.x - .5
	local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
  return Kinetic.look(yaw, pitch)
end

return Kinetic
