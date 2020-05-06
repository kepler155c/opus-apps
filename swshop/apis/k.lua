local w
local r
local jua
local json
local await

local endpoint = "krist.ceriat.net"
local wsEndpoint = "ws://"..endpoint
local httpEndpoint = "http://"..endpoint

local function asserttype(var, name, vartype, optional)
	if not (type(var) == vartype or optional and type(var) == "nil") then
		error(name..": expected "..vartype.." got "..type(var), 3)
	end
end

function init(juai, jsoni, wi, ri)
	asserttype(juai, "jua", "table")
	asserttype(jsoni, "json", "table")
	asserttype(wi, "w", "table", true)
	asserttype(ri, "r", "table")

	jua = juai
	await = juai.await
	json = jsoni
	w = wi
	r = ri
end

local function prints(...)
	local objs = {...}
	for i, obj in ipairs(objs) do
		print(textutils.serialize(obj))
	end
end

local function url(call)
	return httpEndpoint..call
end

local function api_request(cb, api, data)
	local success, url, handle = await(r.request, url(api) .. (api:find("%%?") and "?cc" or "&cc"), {["Content-Type"]="application/json"}, data and json.encode(data))
	if success then
		cb(success, json.decode(handle.readAll()))
		handle.close()
	else
		cb(success)
	end
end

local function authorize_websocket(cb, privatekey)
	asserttype(cb, "callback", "function")
	asserttype(privatekey, "privatekey", "string", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.url and data.url:gsub("wss:", "ws:") or data)
	end, "/ws/start", {
		privatekey = privatekey
	})
end

function address(cb, address)
	asserttype(cb, "callback", "function")
	asserttype(address, "address", "string")

	api_request(function(success, data)
		if data.address then
			data.address.address = address
		end
		cb(success and data and data.ok, data.address or data)
	end, "/addresses/"..address)
end

function addressTransactions(cb, address, limit, offset)
	asserttype(cb, "callback", "function")
	asserttype(address, "address", "string")
	asserttype(limit, "limit", "number", true)
	asserttype(offset, "offset", "number", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.transactions or data)
	end, "/addresses/"..address.."/transactions?limit="..(limit or 50).."&offset="..(offset or 0))
end

function addressNames(cb, address)
	asserttype(cb, "callback", "function")
	asserttype(address, "address", "string")

	api_request(function(success, data)
		cb(success and data and data.ok, data.names or data)
	end, "/addresses/"..address.."/names")
end

function addresses(cb, limit, offset)
	asserttype(cb, "callback", "function")
	asserttype(limit, "limit", "number", true)
	asserttype(offset, "offset", "number", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.addresses or data)
	end, "/addresses?limit="..(limit or 50).."&offset="..(offset or 0))
end

function name(cb, name)
	asserttype(cb, "callback", "function")
	asserttype(name, "name", "string")

	api_request(function(success, data)
		cb(success and data and data.ok, data.name or data)
	end, "/names/"..name)
end

function rich(cb, limit, offset)
	asserttype(cb, "callback", "function")
	asserttype(limit, "limit", "number", true)
	asserttype(offset, "offset", "number", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.addresses or data)
	end, "/addresses/rich?limit="..(limit or 50).."&offset="..(offset or 0))
end

function transactions(cb, limit, offset)
	asserttype(cb, "callback", "function")
	asserttype(limit, "limit", "number", true)
	asserttype(offset, "offset", "number", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.transactions or data)
	end, "/transactions?limit="..(limit or 50).."&offset="..(offset or 0))
end

function latestTransactions(cb, limit, offset)
	asserttype(cb, "callback", "function")
	asserttype(limit, "limit", "number", true)
	asserttype(offset, "offset", "number", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.transactions or data)
	end, "/transactions/latest?limit="..(limit or 50).."&offset="..(offset or 0))
end

function transaction(cb, txid)
	asserttype(cb, "callback", "function")
	asserttype(txid, "txid", "number")

	api_request(function(success, data)
		cb(success and data and data.ok, data.transaction or data)
	end, "/transactions/"..txid)
end

function makeTransaction(cb, privatekey, to, amount, metadata)
	asserttype(cb, "callback", "function")
	asserttype(privatekey, "privatekey", "string")
	asserttype(to, "to", "string")
	asserttype(amount, "amount", "number")
	asserttype(metadata, "metadata", "string", true)

	api_request(function(success, data)
		cb(success and data and data.ok, data.transaction or data)
	end, "/transactions", {
		privatekey = privatekey,
		to = to,
		amount = amount,
		metadata = metadata
	})
end

local wsEventNameLookup = {
	blocks = "block",
	ownBlocks = "block",
	transactions = "transaction",
	ownTransactions = "transaction",
	names = "name",
	ownNames = "name",
	ownWebhooks = "webhook",
	motd = "motd",
	keepalive = "keepalive",
}

local wsEvents = {}

local wsReqID = 0
local wsReqRegistry = {}
local wsEvtRegistry = {}
local wsHandleRegistry = {}

local function newWsID()
	local id = wsReqID
	wsReqID = wsReqID + 1
	return id
end

local function registerEvent(id, event, callback)
	if wsEvtRegistry[id] == nil then
		wsEvtRegistry[id] = {}
	end

	if wsEvtRegistry[id][event] == nil then
		wsEvtRegistry[id][event] = {}
	end

	table.insert(wsEvtRegistry[id][event], callback)
end

local function registerRequest(id, reqid, callback)
	if wsReqRegistry[id] == nil then
		wsReqRegistry[id] = {}
	end

	wsReqRegistry[id][reqid] = callback
end

local function discoverEvents(id, event)
		local evs = {}
		for k,v in pairs(wsEvtRegistry[id]) do
				if k == event or string.match(k, event) or event == "*" then
						for i,v2 in ipairs(v) do
								table.insert(evs, v2)
						end
				end
		end

		return evs
end

wsEvents.success = function(id, handle)
	-- fire success event
	wsHandleRegistry[id] = handle
	if wsEvtRegistry[id] then
		local evs = discoverEvents(id, "success")
		for i, v in ipairs(evs) do
			v(id, handle)
		end
	end
end

wsEvents.failure = function(id)
	-- fire failure event
	if wsEvtRegistry[id] then
		local evs = discoverEvents(id, "failure")
		for i, v in ipairs(evs) do
			v(id)
		end
	end
end

wsEvents.message = function(id, data)
	local data = json.decode(data)
	--print("msg:"..tostring(data.ok)..":"..tostring(data.type)..":"..tostring(data.id))
	--prints(data)
	-- handle events and responses
	if wsReqRegistry[id] and wsReqRegistry[id][tonumber(data.id)] then
		wsReqRegistry[id][tonumber(data.id)](data)
	elseif wsEvtRegistry[id] then
		local evs = discoverEvents(id, data.type)
		for i, v in ipairs(evs) do
			v(data)
		end

		if data.event then
			local evs = discoverEvents(id, data.event)
			for i, v in ipairs(evs) do
				v(data)
			end
		end

		local evs2 = discoverEvents(id, "message")
		for i, v in ipairs(evs2) do
			v(id, data)
		end
	end
end

wsEvents.closed = function(id)
	-- fire closed event
	if wsEvtRegistry[id] then
		local evs = discoverEvents(id, "closed")
		for i, v in ipairs(evs) do
			v(id)
		end
	end
end

local function wsRequest(cb, id, type, data)
	local reqID = newWsID()
	registerRequest(id, reqID, function(data)
		cb(data)
	end)
	data.id = tostring(reqID)
	data.type = type
	wsHandleRegistry[id].send(json.encode(data))
end

local function barebonesMixinHandle(id, handle)
	handle.on = function(event, cb)
		registerEvent(id, event, cb)
	end

	return handle
end

local function mixinHandle(id, handle)
	handle.subscribe = function(cb, event, eventcb)
		local data = await(wsRequest, id, "subscribe", {
			event = event
		})
		registerEvent(id, wsEventNameLookup[event], eventcb)
		cb(data.ok, data)
	end

	return barebonesMixinHandle(id, handle)
end

function connect(cb, privatekey, preconnect)
	asserttype(cb, "callback", "function")
	asserttype(privatekey, "privatekey", "string", true)
	asserttype(preconnect, "preconnect", "function", true)
	local url
	if privatekey then
		local success, auth = await(authorize_websocket, privatekey)
		url = success and auth or wsEndpoint
	end
	local id = w.open(wsEvents, url)
	if preconnect then
		preconnect(id, barebonesMixinHandle(id, {}))
	end
	registerEvent(id, "success", function(id, handle)
		cb(true, mixinHandle(id, handle))
	end)
	registerEvent(id, "failure", function(id)
		cb(false)
	end)
end

local domainMatch = "^([%l%d-_]*)@?([%l%d-]+).kst$"
local commonMetaMatch = "^(.+)=(.+)$"

function parseMeta(meta)
	asserttype(meta, "meta", "string")
	local tbl = {meta={}}

	for m in meta:gmatch("[^;]+") do
		if m:match(domainMatch) then
			-- print("Matched domain")

			local p1, p2 = m:match("([%l%d-_]*)@"), m:match("@?([%l%d-]+).kst")
			tbl.name = p1
			tbl.domain = p2

		elseif m:match(commonMetaMatch) then
			-- print("Matched common meta")

			local p1, p2 = m:match(commonMetaMatch)

			tbl.meta[p1] = p2

		else
			-- print("Unmatched standard meta")

			table.insert(tbl.meta, m)
		end
		-- print(m)
	end
	-- print(textutils.serialize(tbl))
	return tbl
end

return {
	init = init,
	address = address,
	addressTransactions = addressTransactions,
	addressNames = addressNames,
	addresses = addresses,
	name = name,
	rich = rich,
	transactions = transactions,
	latestTransactions = latestTransactions,
	transaction = transaction,
	makeTransaction = makeTransaction,
	connect = connect,
	parseMeta = parseMeta,
}
