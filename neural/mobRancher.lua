--[[
	Changed to use a 2-high mob (smaller mobs may work ?)
	Updated due to entity.look working correctly now.

	The mob looks head-on to the lever. Make sure the
	lever is accessible by the mob.

	Laser is now optional - if no laser, the mobs will be
	punched (or provide a stick). Best mob may be a
	skeleton (unlimited ammo).

	Feeding hand has been changed to off-hand.
]]

local Array  = require('opus.array')
local Config = require('opus.config')
local neural = require('neural.interface')
local Sound  = require('opus.sound')
local Map    = require('opus.map')

local os = _G.os

local config = Config.load('mobRancher', {
	animal = 'Cow',
	maxAdults = 12,
})

local WALK_SPEED = 1.5

neural.assertModules({
	'plethora:sensor',
	'plethora:scanner',
	--'plethora:laser',
	'plethora:kinetic',
	'plethora:introspection',
})

local caninimals = config.animals or { [ config.animal ] = true }
local animals = { }
for k in pairs(caninimals) do
	animals[k] = { }
end

local fed = { }

local function resupply()
	local slot = neural.getEquipment().list()[2]
	if slot and slot.count > 32 then
		return
	end
	print('resupplying')
	for _ = 1, 2 do
		local dispenser = Map.find(neural.scan(), 'name', 'minecraft:lever')
		if not dispenser then
			print('dispenser not found')
			break
		end
		if math.abs(dispenser.x) <= 1.2 and math.abs(dispenser.z) <= 1.2 then
			neural.lookAt({ x = dispenser.x, y = dispenser.y, z = dispenser.z })
			for _ = 1, 8 do
				if not neural.use(0, 'off') then
					break
				end
				os.sleep(.2)
				neural.getEquipment().suck(2, 64)
			end
			break
		else
			neural.walkTo({ x = dispenser.x, y = 0, z = dispenser.z }, WALK_SPEED, .5)
		end
	end
end

local function breed(entity)
	print('breeding ' .. entity.name)

	neural.walkTo(entity, WALK_SPEED, 1)
	entity = neural.getMetaByID(entity.id)
	if entity then
		neural.lookAt(entity)
		if neural.use(1, 'off') then
			entity.lastFed = os.clock()
			fed[entity.id] = entity
		end
		os.sleep(.1)
	end
end

local function kill(entity)
	print('killing ' .. entity.name)
	neural.walkTo(entity, WALK_SPEED, (neural.fire or neural.shoot) and 2.5 or .5)
	entity = neural.getMetaByID(entity.id)
	if entity then
		neural.lookAt(entity)
		if neural.fire or neural.shoot then
			neural.shootAt(entity)
		else
			neural.swing()
		end
		Sound.play('entity.firework.launch')
		os.sleep(.2)
	end
end

local function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

local function getEntities()
	return shuffle(Array.filter(neural.sense(), function(entity)
		if animals[entity.name] then
			if not animals[entity.name].height then
				entity = neural.getMetaByID(entity.id)
				if entity and not entity.isChild and entity.motionX == 0 and entity.motionZ == 0 then
					animals[entity.name].height = entity.y
					return true
				end
			elseif entity.y == animals[entity.name].height then
				return true
			end
		end
	end))
end

local function getHungry(entities)
	for _,v in pairs(entities) do
		if not fed[v.id] or os.clock() - fed[v.id].lastFed > 60 then
			return v
		end
	end
end

local function getCount(entities, name)
	local c = 0
	for _, v in pairs(entities) do
		if v.name == name then
			c = c + 1
		end
	end
	print(name .. ' ' .. c)
	return c
end

local function getKillable(entities)
	print('map: ' .. Map.size(fed))
	if Map.size(fed) > 1000 then
		fed = { }
	end
	for name in pairs(animals) do
		if getCount(entities, name) > config.maxAdults then
			return Array.find(entities, 'name', name)
		end
	end
end

while true do
	resupply()

	local entities = getEntities()
	local killable = getKillable(entities)

	if killable then
		kill(killable)
	else
		local entity = getHungry(entities)
		if entity then
			breed(entity)
		else
			os.sleep(5)
		end
	end
end
