--[[
	Breed either cows or sheep.
	Must be run on a mob with the same height.
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
	'plethora:laser',
	'plethora:kinetic',
	'plethora:introspection',
})

local fed = { }

local function resupply()
	local slot = neural.getEquipment().list()[1]
	if slot and slot.count > 32 then
		return
	end
	print('resupplying')
	for _ = 1, 2 do
		local dispenser = Map.find(neural.scan(), 'name', 'minecraft:dispenser')
		if not dispenser then
			print('dispenser not found')
			break
		end
		if math.abs(dispenser.x) <= 1 and math.abs(dispenser.z) <= 1 then
			neural.lookAt(dispenser)
			for _ = 1, 8 do
				neural.use(0, 'off')
				os.sleep(.2)
				neural.getEquipment().suck(1, 64)
			end
			break
		else
			neural.walkTo({ x = dispenser.x, y = 0, z = dispenser.z }, WALK_SPEED)
		end
	end
end

local function breed(entity)
	print('breeding')
	entity.lastFed = os.clock()
	fed[entity.id] = entity

	neural.walkTo(entity, WALK_SPEED, 1)
	entity = neural.getMetaByID(entity.id)
	if entity then
		neural.lookAt(entity)
		neural.use(1)
		os.sleep(.1)
	end
end

local function kill(entity)
	print('killing')
	neural.walkTo(entity, WALK_SPEED, 2.5)
	entity = neural.getMetaByID(entity.id)
	if entity then
		neural.lookAt(entity)
		neural.fireAt({ x = entity.x, y = 0, z = entity.z })
		Sound.play('entity.firework.launch')
		os.sleep(.2)
	end
end

local function getEntities()
	local sheep = Array.filter(neural.sense(), function(entity)
		if entity.name == 'Sheep' and entity.y > -.5 then
			return true
		end
	end)
	if #sheep > config.maxAdults then
		return sheep
	end

	return Map.filter(neural.sense(), function(entity)
		if entity.name == config.animal and entity.y > -.5 then
			return true
		end
	end)
end

local function getHungry(entities)
	for _,v in pairs(entities) do
		if not fed[v.id] or os.clock() - fed[v.id].lastFed > 60 then
			return v
		end
	end
end

local function randomEntity(entities)
	local r = math.random(1, Map.size(entities))
	local i = 1
	for _, v in pairs(entities) do
		i = i + 1
		if i > r then
			return v
		end
	end
end

while true do
	resupply()

	local entities = getEntities()

	if Map.size(entities) > config.maxAdults then
		kill(randomEntity(entities))
	else
		local entity = getHungry(entities)
		if entity then
			breed(entity)
		else
			os.sleep(5)
		end
	end
end
