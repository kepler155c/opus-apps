local Sound  = require('opus.sound')
local Util   = require('opus.util')

local fs     = _G.fs
local os     = _G.os
local turtle = _G.turtle

local STARTUP_FILE = 'usr/autorun/miloWater.lua'
if not fs.exists(STARTUP_FILE) then
	Util.writeFile(STARTUP_FILE,
		[[os.sleep(2)
shell.openForegroundTab('packages/miloApps/apps/water')]])
end

local played = false

local function play(sound)
	if not played then
		--played = true
		Sound.play(sound)
	end
end

while true do
	if turtle.placeDown('minecraft:bucket:0') then
		play('item.bucket.fill')
	end
	if turtle.placeDown('minecraft:glass_bottle:0') then
		play('item.bottle.fill')
	end

	for k,v in pairs(turtle.getInventory()) do
		if v.name == 'minecraft:concrete_powder' or v.name == 'minecraft:gravel' then
			turtle.select(k)
			play('block.gravel.break')
			for _ = 1, v.count do
				turtle.placeDown()
				turtle.digDown()
			end
		end
	end
	os.pullEvent('turtle_inventory')
	played = false
end
