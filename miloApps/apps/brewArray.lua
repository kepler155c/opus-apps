--[[
authors: jakedacatman and kepler155c

pastebin run uzghlbnc
package install core
package install milo
reboot

Use multiple brewing stands at once to brew potions.
SETUP:
	Place an introspection module into the turtles inventory.
	Connect turtle to milo network with a wired modem.
	Connect turtle to a second wired modem that is connected to brewing stands ONLY.
	Add as many brewing stands as needed.
CONFIGURATION:
	Set turtle as a "Generic Inventory"
	export blaze powder to slot 5
	import from slots 7-9
Use this turtle for machine crafting.
--]]

local Event      = require('opus.event')
local Util       = require('opus.util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/brewArray.lua'

local function equip(side, item, rawName)
	local equipped = peripheral.getType(side)

	if equipped == item then
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

equip('left', 'plethora:introspection', 'plethora:module:0')
local intro = device['plethora:introspection']
local inv = intro.getInventory()

if not fs.exists(STARTUP_FILE) then
	Util.writeFile(STARTUP_FILE,
		[[os.sleep(1)
shell.openForegroundTab('packages/miloApps/apps/brewArray.lua')]])
end

local brew
local localName

print('detecting wired modem connected to brewing stands...')
for _, dev in pairs(device) do
	if dev.type == 'wired_modem' then
		local list = dev.getNamesRemote()
		brew = { }
		localName = dev.getNameLocal()
		for _, name in pairs(list) do
			if device[name].type ~= 'minecraft:brewing_stand' then
				brew = nil
				break
			end
			table.insert(brew, device[name])
		end
	end
	if brew then
		print('Using wired modem: '  .. dev.name)
		print('Brewing stands: ' .. #brew)
		break
	end
end

if not brew then
	error('Turtle must be connected to a second wired_modem connected to brewing stands only')
end

_G.printError([[Program must be restarted if new brewing stands are added.]])

-- slots 1-3: bottles
-- slot 4: ingredient
-- slot 5: blaze powder

local function process(list)
	local active = false

	for _, brewing in ipairs(Util.shallowCopy(brew)) do
		local s, m = pcall(function()-- block updates can cause errors
			local bs = brewing.list()

			local cooking = bs[1] and bs[2] and bs[3] and bs[4]
			if cooking then
				active = true
			end

			-- fuel
			local fuel = bs[5] or { count = 0 }
			if fuel.count < 1 then
				print('fueling ' ..brewing.name)
				brewing.pullItems(localName, 5, 1, 5)
			end

			if not cooking and (bs[1] or bs[2] or bs[3] or bs[4]) then
				print('pulling from : ' .. brewing.name)
				for i = 1, 4 do
					brewing.pushItems(localName, i, 1, 6 + i)
				end
			end

			if not cooking and list[1] and list[2] and list[3] and list[4] then
				print('brewing : ' .. brewing.name)
				for i = 1, 4 do
					brewing.pullItems(localName, i, 1, i)
					list[i].count = list[i].count - 1
					if list[i].count == 0 then
						list[i] = nil
					end
				end

				-- push brewing stand to end of list
				Util.removeByValue(brew, brewing)
				table.insert(brew, brewing)
			end
		end)
		if not s and m then
			_G.printError(m)
		end
	end

	return active
end

Event.on('turtle_inventory', function()
	while true do
		if not process(inv.list()) then
			break
		end
		os.sleep(3)
	end
end)

Event.onInterval(5, function()
	-- for some reason, it keeps stalling ...
	os.queueEvent('turtle_inventory')
end)

os.queueEvent('turtle_inventory')
Event.pullEvents()
