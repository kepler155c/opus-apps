--[[
Use multiple furnaces at once to smelt items.

SETUP:
	Place an introspection module into the turtles inventory.
	Connect turtle to milo network with a wired modem.
	Connect turtle to a second wired modem that is connected to furnaces ONLY.
	Add as many furnaces as needed.

CONFIGURATION:
	Set turtle as a "Generic Inventory"
	export coal to slot 2
	import from slot 3

Use this turtle for machine crafting.
--]]

local Event      = require('opus.event')
local Util       = require('opus.util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/miloFurni.lua'
local SMELT_AMOUNT = 8
local INPUT_SLOT   = 1
local FUEL_SLOT    = 2
local OUTPUT_SLOT  = 3

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
shell.openForegroundTab('packages/miloApps/apps/furni')]])
end

local furnaces
local localName

print('detecting wired modem connected to furnaces...')
for _, dev in pairs(device) do
	if dev.type == 'wired_modem' and dev.getNameLocal then
		local list = dev.getNamesRemote()
		furnaces = { }
		localName = dev.getNameLocal()
		for _, name in pairs(list) do
			if device[name].type ~= 'minecraft:furnace' then
				furnaces = nil
				break
			end
			table.insert(furnaces, {
				dev = device[name],
				list = device[name].list(),
			})
		end
	end
	if furnaces then
		print('Using wired modem: '  .. dev.name)
		print('Furnaces: ' .. #furnaces)
		break
	end
end

if not furnaces then
	error('Turtle must be connected to a second wired_modem connected to furnaces only')
end

_G.printError([[Program must be restarted if new furnaces are added.]])

local function getSlot(furnace, slotNo)
	if not furnace.list[slotNo] then
		furnace.list[slotNo] = {
			count = 0
		}
	end
	return furnace.list[slotNo]
end

local function process(list)
	local inItem = list[INPUT_SLOT]
	local inFuel = list[FUEL_SLOT]
	local inReturn = list[OUTPUT_SLOT] or { count = 0 }

	for _, furnace in ipairs(Util.shallowCopy(furnaces)) do
		local s, m = pcall(function()
			if furnace.list[INPUT_SLOT] and furnace.list[INPUT_SLOT].count > 0 then
				furnace.list = furnace.dev.list()
				print('listing ' .. furnace.dev.name)
			end

			-- items to cook
			local cooking = getSlot(furnace, INPUT_SLOT)
			if cooking.count < 64 and inItem and inItem.count > 0 then
				if cooking.count == 0 or cooking.name == inItem.name then
					print('cooking : ' .. furnace.dev.name)
					local count = furnace.dev.pullItems(localName, INPUT_SLOT, SMELT_AMOUNT, INPUT_SLOT)

					if count > 0 then
						inItem.count = inItem.count - count

						cooking.name = inItem.name
						cooking.count = cooking.count + count

						-- push to end of queue
						Util.removeByValue(furnaces, furnace)
						table.insert(furnaces, furnace)
					end
				end
			end

			-- fuel
			local fuel = getSlot(furnace, FUEL_SLOT)
			if fuel.count < 8 and inFuel and inFuel.count > 0 then
				if fuel.count == 0 or fuel.name == inFuel.name then
					print('fueling ' .. furnace.dev.name)
					local count = furnace.dev.pullItems(localName, FUEL_SLOT, 8 - fuel.count, FUEL_SLOT)
					if count > 0 then
						inFuel.count = inFuel.count - count

						fuel.name = inFuel.name
						fuel.count = fuel.count + count
					end
				end
			end

			local result = getSlot(furnace, OUTPUT_SLOT)
			if result.count > 0 then
				if inReturn.count == 0 or result.name == inReturn.name then
					print('pulling from : ' .. furnace.dev.name)
					local count = furnace.dev.pushItems(localName, OUTPUT_SLOT, result.count, OUTPUT_SLOT)

					if count > 0 then
						result.count = result.count - count
						if result.count == 0 then
							furnace.list[OUTPUT_SLOT] = nil
						end

						inReturn.name = result.name
						inReturn.count = inReturn.count + count
					end
				end
			end
		end)
		if not s and m then
			_G.printError(m)
		end
	end
end

Event.on('turtle_inventory', function()
	process(inv.list())
	print('idle')
end)

Event.onInterval(3, function()
	os.queueEvent('turtle_inventory')
end)

os.queueEvent('turtle_inventory')
Event.pullEvents()
