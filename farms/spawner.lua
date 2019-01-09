local Peripheral = require('peripheral')
local Point      = require('point')
local Util       = require('util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/spawner.lua'

local mobTypes = Util.transpose({ ... })

local function equip(side, item, rawName)
	local equipped = Peripheral.lookup('side/' .. side)

	if equipped and equipped.type == item then
		return true
	end

	if not turtle.equip(side, rawName or item) then
		if not turtle.selectSlotWithQuantity(0) then
			error('No slots available')
		end
		turtle.equip(side)
		if not turtle.equip(side, item) then
			error('Unable to equip ' .. item)
		end
	end

	turtle.select(1)
end

equip('left', 'minecraft:diamond_sword')

equip('right', 'plethora:scanner', 'plethora:module:2')
local scanner = device['plethora:scanner']

turtle.reset()
local facing = scanner.getBlockMeta(0, 0, 0).state.facing
turtle.point.heading = Point.facings[facing].heading

local data = scanner.scan()
local spawners = Util.findAll(data, 'name', 'minecraft:mob_spawner')
local spawner = Point.closest(turtle.point, spawners) or error('spawner not in range')

Util.filterInplace(data, function(b)
	return b.name == 'minecraft:chest' or
		 b.name == 'minecraft:dispenser' or
		 b.name == 'minecraft:hopper'
end)
local chest = Point.closest(spawner, data) or error('missing drop off chest')

equip('right', 'plethora:sensor', 'plethora:module:3')
local sensor = device['plethora:sensor']

if not fs.exists(STARTUP_FILE) then
  Util.writeFile(STARTUP_FILE,
    [[os.sleep(1)
shell.openForegroundTab('spawner.lua')]])
  print('Autorun program created: ' .. STARTUP_FILE)
end

turtle.setMovementStrategy('goto')
turtle.setPolicy(turtle.policies.attack)

local function dropOff()
	local inv = turtle.getSummedInventory()
	for _, slot in pairs(inv) do
		if slot.count >= 16 then
			if turtle.getFuelLevel() < 5000 then
				turtle.refuel(slot.name, 16)
			end
		end
	end

	inv = turtle.getSummedInventory()
	for _, slot in pairs(inv) do
		if slot.count >= 16 or turtle.getSlot(8).count > 0 then
			turtle.eachFilledSlot(function(s)
				if s.name ~= 'plethora:module' then
					turtle.dropDownAt(chest, s.name, s.count)
				end
			end)
			break
		end
	end
	turtle.select(1)
end

local function normalize(b)
	b.x = Util.round(b.x) + turtle.point.x
	b.y = Util.round(b.y) + turtle.point.y
	b.z = Util.round(b.z) + turtle.point.z

	return b.x >= spawner.x - 4 and b.x <= spawner.x + 4 and
			   b.y >= spawner.y - 4 and b.y <= spawner.y + 4 and
	       b.z >= spawner.z - 4 and b.z <= spawner.z + 4
end

local function aboveAttack(b)
	if turtle.attackDownAt(b) then
		repeat until not turtle.attackDown()
	end
end

local function moveAgainst(b)
	if turtle.faceAgainst(b) then
		repeat until not turtle.attack()
		return true
	end
end

local function getAttackStrategy(name)
	local Strategies = {
		Pig = {
			attack = aboveAttack,
		},
		Default = {
			attack = moveAgainst,
		}
	}

	return Strategies[name] or Strategies.Default
end

while true do
	local blocks = sensor.sense()
	local mobs = Util.filterInplace(blocks, function(b)
		if mobTypes[b.name] then
			return normalize(b)
		end
	end)

	if turtle.getFuelLevel() == 0 then
		error('Out of fuel')
	end

	if #mobs == 0 then
		os.sleep(3)
	else
		Point.eachClosest(turtle.point, mobs, function(b)
			local strategy = getAttackStrategy(b.name)
			if strategy.attack(b) then
				while true do
					local mob = sensor.getMetaByID(b.id)
					if not mob or Util.empty(mob) then
						break
					end
					normalize(mob)
					if not strategy.attack(mob) then
						break
					end
				end
			end
		end)
	end

	dropOff()
end
