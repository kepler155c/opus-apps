--[[
Send items to a players enderchest.
--]]

local Event  = require('opus.event')
local Util   = require('opus.util')

local device = _G.device
local fs     = _G.fs
local os     = _G.os
local turtle = _G.turtle

local STARTUP_FILE = 'usr/autorun/enderchest.lua'

local enderChest = device.manipulator and
	device.manipulator.getEnder or
	error('Must be connected to a manipulator with a bound introspection module')

if not fs.exists(STARTUP_FILE) then
	Util.writeFile(STARTUP_FILE,
		[[os.sleep(1)
shell.openForegroundTab('packages/miloApps/apps/enderchest')]])
end

local directions = Util.transpose {
	'north', 'south', 'east', 'west', 'up', 'down'
}

Event.on('turtle_inventory', function()
	local s, m = pcall(function()
		local direction

		for _, d in pairs(enderChest().getTransferLocations()) do
			if directions[d] then
				direction = d
				break
			end
		end

		if not direction then
			error('Unable to determine transfer direction')
		end

		turtle.eachFilledSlot(function(s)
			print('sending')
			enderChest().pullItems(direction, s.index)
		end)
	end)
	if not s and m then
		_G.printError(m)
	end
	print('idle')
end)

Event.onInterval(5, function()
	-- for some reason, it keeps stalling ...
	os.queueEvent('turtle_inventory')
end)

os.queueEvent('turtle_inventory')
Event.pullEvents()
