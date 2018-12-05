_G.requireInjector(_ENV)

local Util   = require('util')

local fs     = _G.fs
local os     = _G.os
local turtle = _G.turtle

local STARTUP_FILE = 'usr/autorun/miloWater.lua'
if not fs.exists(STARTUP_FILE) then
	Util.writeFile(STARTUP_FILE,
		[[os.sleep(2)
shell.openForegroundTab('packages/milo/apps/water')]])
end

while true do
	turtle.placeDown('minecraft:bucket:0')
	turtle.placeDown('minecraft:glass_bottle:0')
	for k,v in pairs(turtle.getInventory()) do
		if v.name == 'minecraft:concrete_powder' then
			turtle.select(k)
			for _ = 1, v.count do
				turtle.placeDown()
				turtle.digDown()
			end
		end
	end
	os.pullEvent('turtle_inventory')
end
