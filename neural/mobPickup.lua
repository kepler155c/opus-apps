--[[
	Pickup items from a flat area and drop into a hopper.
	Must be a 1 high mob
]]

local neural = require('neural.interface')
local Point  = require('opus.point')
local Sound  = require('opus.sound')
local Util   = require('opus.util')

local os = _G.os

neural.assertModules({
	'plethora:sensor',
	'plethora:scanner',
	'plethora:kinetic',
	'plethora:introspection',
})

local function dropOff()
	print('dropping')

	local hoppers = Util.filter(neural.scan(), function(h)
		return h.name == 'minecraft:hopper' and h.y == -1
	end)

	local _, b = next(hoppers)
	if b then
		neural.walkTo({ x = b.x, y = 0, z = b.z }, 2)

		b = neural.getBlockMeta(0, -1, 0)
		if b.name == 'minecraft:hopper' then
			print('dropped')
			neural.getEquipment().drop(1)
			neural.getEquipment().drop(2)
			os.sleep(1)
		end
	end
end

local function pickup(id)
	local b = neural.getMetaByID(id)
	if b then
		neural.walkTo(b, 2)

		local amount = neural.getEquipment().suck()
		print('sucked: ' .. amount)
		if amount > 0 then
			Sound.play('entity.item.pickup')
			return true
		end
	end
end

while true do
	local sensed = Util.reduce(neural.sense(), function(acc, s)
		if Util.round(s.y) == 0 and s.name == 'Item' then
			acc[s.id] = s
		end
		return acc
	end, { })

	local pt = { x = 0, y = 0, z = 0 }
	while true do
		local b = Point.closest(pt, sensed)
		if not b then
			os.sleep(5)
			break
		end
		sensed[b.id] = nil

		if pickup(b.id) then
			pt = b
		else
			dropOff()
			break
		end
	end
end

