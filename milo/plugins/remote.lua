local Event  = require('opus.event')
local itemDB = require('core.itemDB')
local Milo   = require('milo')
local Socket = require('opus.socket')

local device = _G.device

local context = Milo:getContext()

local function getNameSafe(v)
	local name
	local s, m = pcall(function()
		name = v.getName()
	end)
	if not s then
		_G._syslog(m)
	end
	return name
end

local function getManipulatorForUser(user)
	for _,v in pairs(device) do
		if v.type == 'manipulator' and v.getName and getNameSafe(v) == user then
			return v
		end
	end
end

local function compactList(list)
	local c = { }
	for k,v in pairs(list) do
		c[k]= table.concat({ v.has_recipe and 1 or 0, v.count, v.displayName }, ':')
	end
	return c
end

local function client(socket)
	_G._syslog('REMOTE: connection from ' .. socket.dhost)

	local user = socket:read(2)
	if not user then
		return
	end

	local manipulator = getManipulatorForUser(user)
	if not manipulator then
		_G._syslog('REMOTE: Manipulator with introspection module bound with user not found. Closing connection.')
		socket:write({
			msg = 'Manipulator not found'
			})
		socket:close()
		return
	end

	_G._syslog('REMOTE: all good')
	socket:write({
		data = 'ok',
	})

	local function makeNode(devType)
		local devName = user .. ':' .. devType
		local adapter = device[devName]
		if adapter then
			return {
				adapter = adapter,
				name = devName,
			}
		end
	end

	repeat
		local data = socket:read()
		if not data then
			break
		end

		socket.co = coroutine.running()

		if data.request == 'scan' then -- full scan of all inventories
			local items = Milo:mergeResources(Milo:listItems(true))
			socket:write({
				type = 'list',
				list = compactList(items),
			})

		elseif data.request == 'list' then
			local items = Milo:mergeResources(Milo:listItems())
			socket:write({
				type = 'list',
				list = compactList(items),
			})

		elseif data.request == 'deposit' then
			local function deposit()
				local node = makeNode(data.source or 'inventory')
				if node then
					local slot = node.adapter.getItemDetail(data.slot)
					if slot then
						if context.storage:import(node, data.slot, slot.count, slot) > 0 then
							local item = Milo:getItem(slot)
							if item then
-- TODO: This generates multile messages for the same item
-- use a callback system using a UID for the message

								socket:write({
									type = 'received',
									key = item.key,
									count = item.count,
								})
							end
						end
					end
				end
			end

			Milo:queueRequest({ }, deposit)

		elseif data.request == 'transfer' then
			local count = data.count

			if count == 'stack' then
				count = itemDB:getMaxCount(data.item)
			elseif count == 'all' then
				local item = Milo:getItem(data.item)
				count = item and item.count or 0
			end

			local function transfer(request)
				local target = makeNode('inventory')
				if target then
					local amount = context.storage:export(
						target,
						nil,
						request.requested,
						data.item)

					local item = Milo:listItems()[request.key]
					socket:write({
						type = 'transfer',
						key = request.key,
						requested = request.requested,
						current = item and item.count or 0,
						count = amount,
						craft = request.craft,
					})
				end
			end

			local request = Milo:makeRequest(data.item, count, transfer)
			if (request.craft + request.count == 0) or
				 (request.craft > 0 and request.count == 0) then
				socket:write({
					type = 'transfer',
					key = request.key,
					requested = request.requested,
					count = request.current,
					craft = request.craft,
				})
			end
		else
			for _,v in pairs(context.plugins.remoteHandler or { }) do
				if v.messages and v.messages[data.request] then
					v.callback(user, data, socket)
				end
			end
		end
	until not socket.connected

	_G._syslog('REMOTE: disconnected from ' .. socket.dhost)
end

local handler

local function listen()
	if device.wireless_modem then
		handler = Event.addRoutine(function()
			_G._syslog('REMOTE: listening on port 4242')
			while true do
				local socket = Socket.server(4242)
				Event.addRoutine(function()
					client(socket)
					socket:close()
				end)
			end
		end)
	end
end

Event.on({ 'device_attach', 'device_detach' }, function(_, name)
	if name == 'wireless_modem' then
		if handler then
			handler:terminate()
			handler = nil
			_G._syslog('REMOTE: wireless modem disconnected')
		else
			listen()
		end
	end
end)

listen()
