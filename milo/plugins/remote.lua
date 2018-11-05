local Event  = require('event')
local itemDB = require('itemDB')
local Milo   = require('milo')
local Socket = require('socket')
local Sync   = require('sync')

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
	_G._debug('connection from ' .. socket.dhost)

	local user = socket:read(2)
	if not user then
		return
	end

	local manipulator = getManipulatorForUser(user)
	if not manipulator then
		socket:write({
			msg = 'Manipulator not found'
			})
		return
	end

	socket:write({
		data = 'ok',
	})

	repeat
		local data = socket:read()
		if not data then
			break
		end

		if data.request == 'list' then
			local items = Milo:mergeResources(Milo:listItems())
			socket:write(items)

		elseif data.request == 'deposit' then
			local function deposit()
				Sync.sync(turtle, function()
					if data.slot == 'shield' then
						manipulator.getEquipment().pushItems(
							context.localName,
							SHIELD_SLOT,
							data.count)
					else
						manipulator.getInventory().pushItems(
							context.localName,
							data.slot,
							data.count)
					end
					Milo:clearGrid()
				end)
			end

			local list = Milo:listItems()
			local current = list[data.key] and list[data.key].count or 0

			socket:write({
				key = data.key,
				current = current,
			})

			Milo:queueRequest({ }, deposit)

		elseif data.request == 'transfer' then
			local count = data.count

			if count == 'stack' then
				count = itemDB:getMaxCount(data.item)
			elseif count == 'all' then
				local item = Milo:getItem(Milo:listItems(), data.item)
				count = item and item.count or 0
			end

			local function transfer(request)
				Sync.sync(turtle, function()
					local transferred = context.storage:export(
						context.localName,
						nil,
						request.count,
						data.item)

					turtle.eachFilledSlot(function(slot)
						manipulator.getInventory().pullItems(
							context.localName,
							slot.index,
							transferred)
					end)
				end)
			end

			local request = Milo:makeRequest(data.item, count, transfer)

			socket:write(request)
		end
	until not socket.connected

	_G._debug('disconnected from ' .. socket.dhost)
end

if device.wireless_modem then
	Event.addRoutine(function()
		_G._debug('Milo: listening on port 4242')
		while true do
			local socket = Socket.server(4242)
			Event.addRoutine(function()
				client(socket)
				socket:close()
			end)
		end
	end)
end
