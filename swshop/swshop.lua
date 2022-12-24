local Config = require('opus.config')
local Krist  = require('swshop.krist')
local Util   = require('opus.util')

local fs        = _G.fs
local os        = _G.os

local w   = require("swshop.w")
local r   = require("swshop.r")
local k   = require("swshop.k")
local jua = require("swshop.jua")

local await     = jua.await
local device    = _G.device
local json      = { encode=textutils.serializeJSON, decode = textutils.unserialiseJSON }
local rs        = _G.rs
local textutils = _G.textutils

local chat = device['plethora:chat']
local storage = Config.load('storage')

Util.each(rs.getSides(), function(side) rs.setOutput(side, false) end)

local defaultKristNode = "https://krist.dev"

local node = ({ ... })[1] or error('Node name is required')
local config = storage[node]
local privatekey = config.isPrivateKey and config.password or Krist.toKristWalletFormat(config.password)
local nodeurl = config.syncNode or defaultKristNode
local address = Krist.makev2address(privatekey)
local rsSide = config.rsSide or 'top'

r.init(jua)
w.init(jua)
k.setNodeUrl(nodeurl:gsub("https?://", ""))
k.init(jua, json, w, r)

jua.on("terminate", function()
	rs.setOutput(rsSide, false)
	jua.stop()
	_G.printError("Terminated")
end)

local function getItemDetails(item)
	local f = fs.open('usr/config/shop', "r")
	if f then
		local t = f.readAll()
		f.close()
		t = textutils.unserialize(t)
		for key, v in pairs(t) do
			if v.name == item then
				return key, v
			end
		end
		return nil, {}
	end
end

local function logTransaction(transaction, details)
	local transactions = Util.readTable('/usr/swshop.log') or { }
	transaction = Util.shallowCopy(transaction)
	Util.merge(transaction, details)
	table.insert(transactions, transaction)
	Util.writeTable('/usr/swshop.log', transactions)
	os.queueEvent('shop_transaction', transaction)
end

local function handleTransaction(transaction)
	local from = transaction.from
	local to = transaction.to
	local value = transaction.value
	if to ~= address or not transaction.metadata then return end

	local metadata = k.parseMeta(transaction.metadata)
	if not metadata.domain or metadata.domain ~= config.domain then return end

	local recipient = metadata.meta and (metadata.meta["return"] or from) or from
	print("Handling transaction from ", recipient)
	print('purchase: ' .. tostring(metadata.name))
	print('value: ' .. value)

	local t = {
		to = transaction.to,
		from = transaction.from,
		value = transaction.value,
		txid = transaction.id,
		id = metadata.name,
		time = math.floor(os.epoch('utc')/1000),
		recipient = recipient,
	}

	local function refundTransaction(amount, reason)
		print("Refunding to", recipient)
		await(k.makeTransaction, privatekey, recipient, amount, reason)
		logTransaction(t, { refund = amount, reason = reason })
	end

	local id, item = getItemDetails(metadata.name)
	t.itemId, t.price = id, tonumber(item.price)

	if not t.itemId or not t.price then
		print('invalid item')
		logTransaction(t, { reason = 'invalid item' })
		if config.refundInvalid then
			return refundTransaction(value, "error=Item specified is not valid")
		end
		return -- multiple store setup
	end

	if value < t.price then
		print('value too low')
		return refundTransaction(value, "error=Please pay the price listed on-screen.")
	end

	if item.shares then
		local amount = t.value - (t.value % t.price)
		for _, share in pairs(item.shares) do
			local cut = math.floor(amount * share.rate) -- Don't include fractional Krist
			print("Sent shares of "..cut.." to "..share.address)
			await(k.makeTransaction, privatekey, share.address, cut, share.meta)
		end
	end

	local count = math.floor(value / t.price)
	local uid = math.random()
	print(string.format('requesting %d of %s', count, t.itemId))
	os.queueEvent('shop_provide', t.itemId, count, uid)
	local timerId = os.startTimer(60)

	while true do
		local e, p1, p2 = os.pullEvent()
		if e == 'turtle_inventory' then
			os.cancelTimer(timerId)
			timerId = os.startTimer(60)
		elseif e == 'timer' and p1 == timerId then
			print('timed out waiting for provide')
			refundTransaction(value, "error=Timed out attempting to provide items")
			break

		elseif e == 'shop_provided' and p1 == uid then
			local extra = value - (t.price * p2)
			logTransaction(t, { purchased = p2 })
			local msg = string.format('PURCHASE: %s bought %d %s for %s',
			recipient, p2, t.itemId, t.price * p2)
			if chat and chat.tell then
				pcall(chat.tell, msg)
			end
			if extra > 0 then
				print('extra: ' .. extra)
				refundTransaction(extra, "message=Here's your change!")
			end
			break
		end
	end
end

local function connect()
	print('opening store for: ' .. config.domain)
	print('using address: ' .. address)

	local success, ws = await(k.connect, privatekey)
	assert(success, "Failed to get websocket URL")

	print("Connected to websocket.")
	rs.setOutput(rsSide, true)

	success = await(ws.subscribe, "ownTransactions", function(data)
		local transaction = data.transaction
		handleTransaction(transaction)
	end)

	await(ws.subscribe, "keepalive", function(data)
		local state = rs.getOutput(rsSide)
		rs.setOutput(rsSide, not state)
	end)

	assert(success, "Failed to subscribe to event")
end

local s, m = pcall(function()
	jua.go(function()
		print("Ready")
		connect()
	end)
end)

rs.setOutput(rsSide, false)
if not s then
	error(m, 2)
end
