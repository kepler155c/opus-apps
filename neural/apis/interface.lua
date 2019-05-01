local Angle = require('neural.angle')

local os         = _G.os
local peripheral = _G.peripheral

local Neural = { }

function Neural.assertModules(modules)
	local all = {
		[ 'plethora:glasses' ] = 'Overlay glasses',
		[ 'plethora:sensor' ] = 'Entity sensor',
		[ 'plethora:scanner' ] = 'Block scanner',
		[ 'plethora:introspection' ] = 'Introspection module',
		[ 'plethora:kinetic' ] = 'Kinetic augment',
		[ 'plethora:laser' ] = 'Laser',
	}

	for _, m in pairs(modules) do
		if not Neural.hasModule(m) then
			print('Required:')
			for _, v in pairs(modules) do
				print(' * ' .. (modules[v] or v))
			end
			print('')
			error('Missing: ' .. (all[m] or m))
		end
	end
end

function Neural.yap(spt, dpt)
	local x, y, z = dpt.x - spt.x, dpt.y - spt.y, dpt.z - spt.z
	local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
	local yaw = math.atan2(-x, z)

  return math.deg(yaw), math.deg(pitch)
end

function Neural.launchTo(pt, strength)
	local yaw = math.deg(math.atan2(pt.x, -pt.z))
	if not strength then
		local dist = math.sqrt(
					 math.pow(pt.x, 2) +
					 math.pow(pt.z, 2))
		strength = math.sqrt(math.max(32, dist) / 3)
	end
	Neural.launch(yaw, 225, strength or 1)
end

function Neural.walkTo(pt, speed)
  Neural.walk(pt.x, pt.y, pt.z, speed)
  os.sleep(1)
  repeat until not Neural.isWalking()
end

function Neural.walkAgainst(pt, radius, speed)
  local angle = math.atan2(pt.x, pt.z)
  local x = pt.x - ((radius or 1) * math.sin(angle))
  local z = pt.z - ((radius or 1) * math.cos(angle))

  Neural.walk(x, 0, z, speed)
  os.sleep(1)
  repeat until not Neural.isWalking()
end

-- flatten equipment functions
function Neural.getEquipmentList()
	local l = Neural.getEquipment and Neural.getEquipment().list() or { }

	for k, v in pairs(l) do
		v.slot = k
	end

	return l
end

function Neural.dropArmor()
	for i = 3, 5 do
		Neural.unequip(i)
	end
end

function Neural.equip(slot)
	return Neural.getEquipment and Neural.getEquipment().suck(slot) or 0
end

function Neural.unequip(slot)
	return Neural.getEquipment and Neural.getEquipment().drop(slot)
end

function Neural.lookAt(pt)
  if pt then
    local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
    return Neural.look(yaw, pitch)
  end
end

function Neural.fireAt(pt, strength)
  local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
  return Neural.fire(yaw, pitch, strength or .5)
end

function Neural.shootAt(pt, strength)
	if Neural.fire then
		return Neural.fireAt(pt, strength)
	else
		Neural.lookAt(pt)
		return Neural.shoot(strength or 1)
	end
end

function Neural.setStatus(s)
  Neural.status = s
end

function Neural.reload()
	return setmetatable(Neural, {
		__index = peripheral.find('neuralInterface')
	})
end

function Neural.testWalk()
  local e = Neural.getMetaByName('kepler155c')
  Neural.walkAgainst(e)
end

return Neural.reload()
