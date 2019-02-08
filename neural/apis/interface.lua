local Interface = { }

local Angle = require('neural.angle')
local Util = require('util')

local device = _G.device
local os     = _G.os

local ni = device.neuralInterface or { }
for k,v in pairs(ni) do
	Interface[k] = v
end

local function yap(pt)
	local x, y, z = pt.x, pt.y + 1, pt.z
	local pitch = -math.atan2(y, math.atan2(-(x - .5), z - .5))
	local yaw = math.deg(math.atan2(-(x - .5), z - .5))

  return math.deg(yaw), math.deg(pitch)
end

function Interface.launchTo(pt, strength)
	local yaw = math.deg(math.atan2(pt.x, -pt.z))
	if not strength then
		local dist = math.sqrt(
					 math.pow(pt.x, 2) +
					 math.pow(pt.z, 2))
		strength = math.sqrt(math.max(32, dist) / 3)
		debug(strength)
	end
	Interface.launch(yaw, 225, strength or 1)
end

function Interface.dropArmor()
	for i = 3, 5 do
		Interface.unequip(i)
	end
end

function Interface.walkTo(pt)
	local s, m = ni.walk(pt.x, pt.y, pt.z)
	if not s then
		_G.printError(m)
	end
  os.sleep(.05)
  while ni.isWalking() do
    os.sleep(0)
  end
end

-- flatten equipment functions
function Interface.getEquipmentList()
	local l = Interface.getEquipment and Interface.getEquipment().list() or { }

	for k, v in pairs(l) do
		v.slot = k
	end

	return l
end

function Interface.equip(slot)
	return Interface.getEquipment and Interface.getEquipment().suck(slot) or 0
end

function Interface.unequip(slot)
	return Interface.getEquipment and Interface.getEquipment().drop(slot)
end

function Interface.getUniqueNames()
	local t = { }
	for _,v in pairs(Interface.sense()) do
		t[v.name] = v.name
	end
	return Util.transpose(t)
end

function Interface.lookAt(pt)
	local yaw, pitch = Angle.towards(pt.x - .5, pt.y + 1, pt.z - .5)
  return Interface.look(yaw, pitch)
end

function Interface.shootAt(entity, strength)
  Interface.lookAt(entity)
  return Interface.shoot(strength or 1)
end

function Interface.shootAt2(entity, strength)
	local x, z = entity.x - .5, entity.z - .5

	local function quad(a, b, c)
	  if math.abs(a) < 1e-6 then
	    if math.abs(b) < 1e-6 then
	      return math.abs(c) < 1e-6 and 0, 0
	    else
	      return -c/b, -c/b
	    end
	  else
	    local disc = b*b - 4*a*c
	    if disc >= 0 then
	      disc = math.sqrt(disc)
	      a = 2*a
	      return (-b-disc)/a, (-b+disc)/a
	    end
	  end
	end

	 local v = .025 -- velocity of arrow

	 local tvx = entity.motionX
	 local tvz = entity.motionZ
	 local a = tvx*tvx + tvz*tvz - v*v
	 local b = 2 * (tvx * x + tvz * z)
	 local c = x * x + z * z
	 local t0, t1 = quad(a, b, c)
	 if t0 then
	   local t = math.min(t0, t1)
	   if t < 0 then
	     t = math.max(t0, t1)
	   end
	   if t > 0 then
	   --Util.print({ x, t, tvx, x + tvx * t })
	     x = x + tvx * t
	     z = z + tvz * t
	   end
	 end

	local yaw = math.deg(math.atan2(-(x - .5), z - .5))
	local pitch = -math.deg(math.atan2(entity.y, math.sqrt(x * x + z * z)))

  Interface.look(yaw, pitch) -- pitch is broken
  return Interface.shoot(strength or 1)
end

function Interface.setStatus(s)
  ni.status = s
end

return Interface
