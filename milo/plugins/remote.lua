local Event  = require('event')
local Milo   = require('milo')
local Socket = require('socket')

local device      = _G.device
local manipulator = device.manipulator_1
local turtle      = _G.turtle

local context = Milo:getContext()

local function client(socket)
	debug('connection from ' .. socket.dhost)

	repeat
		local data = socket:read()
		if not data then
			break
		end
		if data.request == 'list' then
			local items = Milo:listItems()
			Milo:mergeResources(items)
			socket:write(items)

		elseif data.request == 'transfer' then
			context.inventoryAdapter:provide(
				data.item,
				data.count,
				nil,
				context.localName)

			turtle.eachFilledSlot(function(slot)
				manipulator.getInventory().pullItems(
					context.localName,
					slot.index,
					slot.count)
			end)

			local items = Milo:listItems()
			Milo:mergeResources(items)
			socket:write(items)
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
			end)
		end
	end)
end
