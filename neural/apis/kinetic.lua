local Angle = require('neural.angle')
local Util  = require('util')

local device = _G.device

local module = device['plethora:kinetic'] or error('Missing kinetic')

local Kinetic = Util.shallowCopy(module)

function Kinetic.lookAt(pt)
	local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
  return Kinetic.look(yaw, pitch)
end

return Kinetic
