local Event  = require('event')
local Milo   = require('milo')
local Socket = require('socket')

local device = _G.device
local turtle = _G.turtle

local SHIELD_SLOT = 2

local context = Milo:getContext()

local function getManipulatorForUser(user)
	for _,v in pairs(device) do
		if v.type == 'manipulator' and v.getName and v.getName() == user then
			return v
		end
	end
end

local function client(socket)
	debug('connection from ' .. socket.dhost)

	local user = socket:read(2)
	if not user then
		return
	end

	local manipulator = getManipulatorForUser(user)
	if not manipulator then
		return
	end

	repeat
		local data = socket:read()
		if not data then
			break
		end
debug('remote: ' .. data.request)
		if data.request == 'list' then
			local items = Milo:refreshItems()
			Milo:mergeResources(items)
			socket:write(items)

		elseif data.request == 'deposit' then
			local count

			if data.slot == 'shield' then
				count = manipulator.getEquipment().pushItems(
					context.localName,
					SHIELD_SLOT,
					64)
			else
				count = manipulator.getInventory().pushItems(
					context.localName,
					data.slot,
					64)
			end
			socket:write({ count = count })
			Milo:clearGrid()

		elseif data.request == 'transfer' then
			local count = Milo:provideItem(data.item, data.count, function(amount, currentCount)
				amount = context.storage:export(
					context.localName,
					nil,
					amount,
					data.item)

				turtle.eachFilledSlot(function(slot)
					manipulator.getInventory().pullItems(
						context.localName,
						slot.index,
						slot.count)
				end)
				return currentCount - amount
			end)

			socket:write({ count = count })
		end
	until not socket.connected

	debug('disconnected from ' .. socket.dhost)
end

if device.wireless_modem then
	Event.addRoutine(function()
		debug('Milo: listening on port 4242')
		while true do
			local socket = Socket.server(4242)
			Event.addRoutine(function()
				client(socket)
				socket:close()
			end)
		end
	end)
end
