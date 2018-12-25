_G.requireInjector(_ENV)

local Point      = require('point')
local Util       = require('util')

local device     = _G.device
local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local args = { ... }
local mobType = args[1] or error('Syntax: attack <mob names>')

local chest    -- a chest/dispenser that is accessible
local mobTypes = Util.transpose(args)

local Runners = {
	Cow     = true,
	Chicken = true,
	Blaze   = false,
}

local function equip(side, item, rawName)
	if peripheral.getType(side) ~= item then
		if not turtle.equip(side, rawName or item) then
			error('Unable to equip ' .. item)
		end
		turtle.select(1)
	end
end

equip('left', 'minecraft:diamond_sword')

equip('right', 'plethora:scanner', 'plethora:module:2')
local scanner = device['plethora:scanner']
local facing = scanner.getBlockMeta(0, 0, 0).state.facing
turtle.point.heading = Point.facings[facing].heading

equip('right', 'plethora:sensor', 'plethora:module:3')
local sensor = device['plethora:sensor']

turtle.setMovementStrategy('goto')
turtle.setPolicy(turtle.policies.attack)

local function findChests()
	if chest then
		return { chest }
	end
	equip('right', 'plethora:scanner', 'plethora:module:2')
	local chests = scanner.scan()
	equip('right', 'plethora:sensor', 'plethora:module:3')

	Util.filterInplace(chests, function(b)
		if b.name == 'minecraft:chest' or
			 b.name == 'minecraft:dispenser' or
			 b.name == 'minecraft:hopper' then
			b.x = Util.round(b.x) + turtle.point.x
			b.y = Util.round(b.y) + turtle.point.y
			b.z = Util.round(b.z) + turtle.point.z
			return true
		end
	end)
	return chests
end

local function dropOff()
	local inv = turtle.getSummedInventory()
	for _, slot in pairs(inv) do
		if slot.count >= 16 then
			if turtle.getFuelLevel() < 1000 then
				turtle.refuel(slot.name, 16)
			end
		end
	end

	inv = turtle.getSummedInventory()
	for _, slot in pairs(inv) do
		if slot.count >= 16 or turtle.getSlot(8).count > 0 then
			if slot.name ~= 'plethora:module' then
				local chests = findChests()
				for c in Point.iterateClosest(turtle.point, chests) do
					if turtle.dropDownAt(c, slot.name) then
						chest = c
						break
					end
				end
			end
		end
	end
	turtle.select(1)
end

local function normalize(b)
	b.x = Util.round(b.x) + turtle.point.x
	b.y = Util.round(b.y) + turtle.point.y
	b.z = Util.round(b.z) + turtle.point.z
end

while true do
	local blocks = sensor.sense()
	local mobs = Util.filterInplace(blocks, function(b)
		if mobTypes[b.name] then
			normalize(b)
			return true
		end
	end)

	if turtle.getFuelLevel() == 0 then
		error('Out of fuel')
	end

	if #mobs == 0 then
		os.sleep(3)
	else
		if Runners[mobType] then
			-- if this mob runs away, just attack next closest
			Point.eachClosest(turtle.point, mobs, function(b)
				if turtle.faceAgainst(b) then
					repeat until not turtle.attack()
				end
			end)
			os.sleep(2) --- give a little time for mobs to calm down
		else
			local attacked = false

			local function attack()
				if turtle.attack() then
					attacked = true
					return attacked
				end
			end

			for mob in Point.iterateClosest(turtle.point, mobs) do
				-- this mob doesn't run, attack and follow until dead
				if turtle.faceAgainst(mob) then
					repeat
						repeat until not turtle.attack()
						mob = sensor.getMetaByID(mob.id)
						if not mob or Util.empty(mob) then
							break
						end
						normalize(mob)
						if not turtle.faceAgainst(mob) then
							break
						end
					until not mob
				end
				if attacked then
					break
				end
			end
		end
	end

	dropOff()
end
