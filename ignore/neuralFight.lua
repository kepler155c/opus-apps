local Angle = require('neural.angle')
local GPS   = require('gps')
local Mobs  = require('neural.mobs')
local ni    = require('neural.interface')
local Point = require('point')
local Util  = require('util')

local os         = _G.os

local RADIUS = 13
local ROTATION = math.pi / 16

local uid = ni.getID and ni.getID() or error('Introspection module is required')
local pos = { x = 0, y = 0, z = 0 }

local function findTargets()
	local l = ni.sense()
	table.sort(l, function(e1, e2)
		return Point.distance(e1, pos) < Point.distance(e2, pos)
	end)

	local targets = { }
	for _,v in ipairs(l) do
		if v.id ~= uid and Mobs.getNames()[v.name] then
			if math.abs(v.y) < 2 and Point.distance(v, pos) < 16 then -- pitch is broken
				table.insert(targets, v)
			end
		end
	end
	return #targets > 0 and targets
end

local function shootAt(targets)
	for _,target in ipairs(targets) do
		target = ni.getMetaByID(target.id)
		if target and target.isAlive and Point.distance(target, pos) < 14 then
			ni.shootAt(target)
		end
	end
end

local potions = Util.filter(
	ni.getEquipmentList(),
	function(a)
		return a.name == 'minecraft:splash_potion'
	end)

local function heal(target)
	local hands = { 'main', 'off' }

	if #potions > 0 and ni.getMetaOwner().health < 10 then
		local yaw, pitch = Angle.away(target.x - .5, 0, target.z - .5)
		ni.look(yaw, pitch)
		ni.use(.01, hands[potions[1].slot])
		ni.launch(yaw, pitch, 1)
		table.remove(potions, 1)
	end
end

local pt = GPS.locate()

while true do
	local targets = findTargets()
	if not targets then
		local cpt = GPS.locate()
		if Point.distance(pt, cpt) > 2 then
			print('walking to starting point')
			local s, m = ni.goTo(pt.x, pt.y, pt.z)
			Util.print({ s, m })
			os.sleep(.05)
			while ni.isWalking() do
				os.sleep(0)
			end
			Util.print('done walking')
		end
		os.sleep(1)
	else
		local target = targets[1]
		local angle = math.atan2(-target.x, -target.z) + ROTATION

		ni.launchTo({
			x = target.x + RADIUS * math.sin(angle),
			y = 0,
			z = target.z + RADIUS * math.cos(angle)
		}, 1)
		os.sleep(.2)

		shootAt(targets)

		heal(target)

		if math.random(1, 3) == 3 then
			ROTATION = -ROTATION
		end
	end
end
