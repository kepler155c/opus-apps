_G.requireInjector()

local Angle = require('neural.angle')
local ni    = require('neural.interface')
local Util  = require('util')

local os         = _G.os

local RADIUS = 13
local ROTATION = math.pi / 16

local args = { ... }
local TARGET = args[1] or error('Syntax: robotWars <targetName>')
local uid = ni.getID and ni.getID() or error('Introspection module is required')

local function findTarget(name)
	for _, v in pairs(ni.sense()) do
		if v.name == name and v.id ~= uid then
			return v
		end
	end
end

local function shootAt(entity)
	local target = ni.getMetaByID(entity.id)
	if target then
		ni.shootAt(target)
	end
end

local enemy = findTarget(TARGET)
local potions = Util.filter(
	ni.getEquipmentList(),
	function(a)
		return a.name == 'minecraft:splash_potion'
	end)

if not enemy then
	print('Current enemies:')
	for _,v in pairs(ni.getUniqueNames()) do
		print(v)
	end
	print()
	error('Invalid enemy')
end

local function heal(target)
	local hands = { 'main', 'off' }

	if #potions > 0 and ni.getMetaOwner().health < 10 then
		local yaw, pitch = Angle.away({ x = target.x, y = 0, z = target.z })
		ni.look(yaw, pitch)
		ni.use(.01, hands[potions[1].slot])
		ni.launch(yaw, pitch, 1)
		table.remove(potions, 1)
	end
end

repeat
	local target = ni.getMetaByID(enemy.id)
	if not target then
		print('lost target')
		break
	end
	local angle = math.atan2(-target.x, -target.z) + ROTATION

	ni.launchTo({
		x = target.x + RADIUS * math.sin(angle),
		y = 0,
		z = target.z + RADIUS * math.cos(angle)
	}, 1)
	os.sleep(.2)

	shootAt(enemy)

	heal(enemy)

	if math.random(1, 3) == 3 then
		ROTATION = -ROTATION
	end
until not target.isAlive

print('Won !')