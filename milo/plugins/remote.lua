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
		return
	end

	repeat
		local data = socket:read()
		if not data then
			break
		end

		if data.request == 'list' then
			local items = Milo:mergeResources(Milo:listItems())
			socket:write(items)

		elseif data.request == 'deposit' then
			if Sync.isLocked(turtle) then
				socket:write({ msg = '' })
			else
				local count

				Sync.sync(turtle, function()
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
					Milo:clearGrid()
				end)

				local list = Milo:listItems()
				local current = list[data.key] and list[data.key].count or 0

				socket:write({
					key = data.key,
					count = count,
					current = current + count,
				})
			end

		elseif data.request == 'transfer' then
			local count = data.count

			if count == 'stack' then
				count = itemDB:getMaxCount(data.item)
			elseif count == 'all' then
				local item = Milo:getItem(Milo:listItems(), data.item)
				count = item and item.count or 0
			end

			local function transfer(amount)
				Sync.sync(turtle, function()
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
				end)

				return amount
			end

			if Sync.isLocked(turtle) then
				socket:write({ msg = 'Turtle in use. please wait...' })
			end

			local provided = Milo:provideItem(data.item, count, transfer)
			provided.transferred = provided.available > 0 and transfer(provided.available) or 0

			socket:write(provided)
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
