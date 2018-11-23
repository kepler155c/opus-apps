_G.requireInjector(_ENV)

local Peripheral = require('peripheral')
local Point      = require('point')
local Util       = require('util')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local args = { ... }
local mobType = args[1] or error('Syntax: attack <mob name>')

local Runners = {
	Cow     = true,
	Chicken = true,
	Blaze   = false,
}

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
local facing = scanner.getBlockMeta(0, 0, 0).state.facing
turtle.point.heading = Point.facings[facing].heading

local scanned = scanner.scan()
local chest = Util.find(scanned, 'name', 'minecraft:chest')
if chest then
	chest.x = Util.round(chest.x) + turtle.point.x
	chest.y = Util.round(chest.y) + turtle.point.y
	chest.z = Util.round(chest.z) + turtle.point.z
end

equip('right', 'plethora:sensor', 'plethora:module:3')

local sensor = device['plethora:sensor']

turtle.setMovementStrategy('goto')

function Point.iterateClosest(spt, ipts)
	local pts = Util.shallowCopy(ipts)
	return function()
		local pt = Point.closest(spt, pts)
		if pt then
			Util.removeByValue(pts, pt)
			return pt
		end
	end
end

local function dropOff()
	if not chest then
		return
	end
	local inv = turtle.getSummedInventory()
	for _, slot in pairs(inv) do
		if slot.count >= 16 then
			turtle.dropDownAt(chest, slot.name)
		end
	end
end

local function normalize(b)
	b.x = Util.round(b.x) + turtle.point.x
	b.y = Util.round(b.y) + turtle.point.y
	b.z = Util.round(b.z) + turtle.point.z
end

while true do
	local blocks = sensor.sense()
	local mobs = Util.filterInplace(blocks, function(b)
		if b.name == mobType then
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
