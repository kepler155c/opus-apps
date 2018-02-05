_G.requireInjector(_ENV)

local Event = require('event')
local Util  = require('util')

local os         = _G.os
local peripheral = _G.peripheral

local ni = peripheral.find("neuralInterface")
if not ni then
	error("Cannot find neuralInterface")
end

local TARGET = 'joebodo'

local function look(entity)
	local x, y, z = entity.x, entity.y, entity.z
	local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
	local yaw = math.atan2(-x, z)

	ni.look(math.deg(yaw), math.deg(pitch))
end

Event.addRoutine(function()
	while true do
		local target = Util.find(ni.sense(), 'name', TARGET)
		if target then
			look(target)
			ni.shoot()
		end
		os.sleep(0)
	end
end)

Event.pullEvents()
