local Equipper = require('turtle.equipper')
local Point    = require('point')

local peripheral = _G.device
local turtle     = _G.turtle

local MAX_FUEL = turtle.getFuelLimit()

if turtle.getFuelLevel() == 0 then
	error('Need some fuel to begin')
end

if not turtle.has('minecraft:bucket') then
	error('bucket required')
end

local swapSide = peripheral.getType('right') == 'modem' and 'left' or 'right'
local scanner = Equipper.equip(swapSide, 'plethora:module:2', 'plethora:scanner')

if not turtle.select('minecraft:bucket') then
	error('bucket required')
end

local s, m = turtle.run(function()
	turtle.set({ status = 'refueling' })
	turtle.setMovementStrategy('goto')

	local facing = scanner.getBlockMeta(0, 0, 0).state.facing
	turtle.setPoint({ x = 0, y = 0, z = 0, heading = Point.facings[facing].heading })

	local blocks = scanner.scan()
	local first, last = blocks[#blocks].y, blocks[1].y

	for y = first, last, -1 do
		if turtle.getFuelLevel() >= (MAX_FUEL - 1000) then
			print('I am full')
			break
		end
		local t = { }
		for _,v in pairs(blocks) do
			if v.y == y then
				if (v.name == 'minecraft:lava' and v.metadata == 0) or
					 (v.name == 'minecraft:flowing_lava' and v.metadata == 0) then
					table.insert(t, v)
				end
			end
		end
		Point.eachClosest(turtle.point, t, function(b)
			if turtle.getFuelLevel() >= (MAX_FUEL - 1000) then
				return true
			end
			turtle.placeDownAt(b)
			turtle.refuel()
			print(turtle.getFuelLevel())
		end)
	end
end)

turtle.gotoY(0)
turtle.go({ x = 0, y = 0, z = 0 })

turtle.set({ status = 'idle' })
turtle.unequip(swapSide)
print('Fuel: ' .. turtle.getFuelLevel())

if not s and m then
	error(m)
end
