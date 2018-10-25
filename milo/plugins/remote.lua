local Event  = require('event')
local Milo   = require('milo')
local Socket = require('socket')

local device = _G.device
local turtle = _G.turtle

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
				socket:close()
			end)
		end
	end)
end
