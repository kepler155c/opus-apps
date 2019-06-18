local Equipper   = require('turtle.equipper')
local Point      = require('point')
local Util       = require('util')

local os         = _G.os
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

Equipper.equipLeft('minecraft:diamond_sword')
local scanner = Equipper.equipRight('plethora:scanner')

local facing = scanner.getBlockMeta(0, 0, 0).state.facing
turtle.point.heading = Point.facings[facing].heading

local sensor = Equipper.equipRight('plethora:sensor')

turtle.setMovementStrategy('goto')
turtle.set({ attackPolicy = 'attack' })

local function findChests()
	if chest then
		return { chest }
	end
	Equipper.equipRight('plethora:scanner')
	local chests = scanner.scan()
	Equipper.equipRight('plethora:sensor')

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
			if turtle.getFuelLevel() < 5000 then
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
	turtle.condense()
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
