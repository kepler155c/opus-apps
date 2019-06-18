local Angle = require('neural.angle')
local Mobs  = require('neural.mobs')
local Point = require('point')

local device = _G.device
local os     = _G.os

local sensor = device['plethora:sensor'] or error('Sensor is required')
local weapon = device['plethora:laser']
local uid = ''

local function shootAt(pt)
	local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
	weapon.fire(yaw, pitch, 4)
end

if not weapon then
	weapon = device['plethora:introspection']
	if not weapon or not weapon.shoot then
		error('Either a laser or a skeleton with introspection module is required')
	end
	uid = weapon.getID()
	shootAt = function(pt)
		local yaw, pitch = Angle.towards(pt.x, pt.y, pt.z)
		weapon.look(yaw, pitch)
		weapon.shoot(1)
	end
end

local function findTargets()
	local pos = { x = 0, y = 0, z = 0 }
	local l = sensor.sense()
	table.sort(l, function(e1, e2)
		return Point.distance(e1, pos) < Point.distance(e2, pos)
	end)

	local targets = { }
	for _,v in ipairs(l) do
		if v.id ~= uid and Mobs.getNames()[v.name] then
			if v.y >= 0 and v.y < 1 then
				table.insert(targets, v)
			end
		end
	end
	return #targets > 0 and targets
end

while true do
	local targets = findTargets()
	if targets then
		for _, entity in ipairs(targets) do
			shootAt(entity, 1)
		end
	end
	os.sleep(.5)
end
