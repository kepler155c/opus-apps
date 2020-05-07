local Array   = require('opus.array')
local neural  = require('neural.interface')
local Point   = require('opus.point')

--[[
	Animate an armor stand or mob. Will just look
	at anything that moves.
]]

local os = _G.os

neural.assertModules({
	'plethora:sensor',
	'plethora:introspection',
})

local pos = { x = 0, y = 0, z = 0 }

local ownerId = neural.getMetaOwner().id
local targets = { }

local function findTargets()
	local now = os.clock()
	local moved = { }

	local l = Array.filter(neural.sense(), function(a)
		if math.abs(a.motionY) > 0 and ownerId ~= a.id then
			local loc = table.concat({ a.x, a.y, a.z }, ':')
			if not targets[a.id] then
				targets[a.id] = { c = now }
			elseif targets[a.id].loc ~= loc then
				targets[a.id].c = now
				table.insert(moved, a)
			end
			targets[a.id].loc = loc
			a.c = targets[a.id].c
			return now - a.c < 5
		end
	end)

	if #moved > 0 then
		table.sort(moved, function(e1, e2)
			return Point.distance(e1, pos) < Point.distance(e2, pos)
		end)
		return moved[1]
	end

	if #l > 1 then
		table.sort(l, function(e1, e2)
			return now - e1.c < now - e2.c
		end)
		return targets[1]
	end
	return l[1]
end

local count = 50

while true do
	local target = findTargets()
	if target then
		count = 0
		neural.lookAt(target)
		os.sleep(0)
	elseif count > 25 then
		neural.lookAt({
			x = math.random(-10, 10),
			y = math.random(-10, 10),
			z = math.random(-10, 10)
		})
		os.sleep(3)
	else
		count = count + 1
		os.sleep(.1)
	end
end

