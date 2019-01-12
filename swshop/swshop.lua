local fs        = _G.fs
local os        = _G.os
local shell     = _ENV.shell

local programDir = fs.getDir(shell.getRunningProgram())
os.loadAPI(programDir .. '/'.. 'json')

local w   = require("w")
local r   = require("r")
local k   = require("k")
local jua = require("jua")

local await     = jua.await
local json      = _G.json
local rs        = _G.rs
local textutils = _G.textutils

rs.setOutput('top', false)

r.init(jua)
w.init(jua)
k.init(jua, json, w, r)

local function Syntax()
  error('Syntax: swshop [domain] [password]')
end

local args = { ... }
local domain = args[1] or Syntax()
local password = args[2] or Syntax()
local privatekey = k.toKristWalletFormat(password)
local address = k.makev2address(privatekey)

jua.on("terminate", function()
  rs.setOutput('top', false)
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
        return key, v.price
      end
    end
  end
end

local function handleTransaction(transaction)
  local from = transaction.from
  local to = transaction.to
  local value = transaction.value
  if to ~= address or not transaction.metadata then return end

  local metadata = k.parseMeta(transaction.metadata)
  if not metadata.domain or metadata.domain ~= domain then return end

  local recipient = metadata.meta and (metadata.meta["return"] or from) or from
  print("Handling transaction from ", recipient)
  print('purchase: ' .. tostring(metadata.name))
  print('value: ' .. value)

  local function refundTransaction(amount, reason)
    print("Refunding to ", recipient)
    await(k.makeTransaction, privatekey, recipient, amount, reason)
  end

  local itemId, price = getItemDetails(metadata.name)
  if not itemId or not price then
    print('invalid item')
    --return refundTransaction(value, "error=Item specified is not valid")
    return -- there could be multiple stores...
  end

  if value < price then
    print('value too low')
    return refundTransaction(value, "error=Please pay the price listed on-screen.")
  end

  local count = math.floor(value / price)
  local uid = math.random()
  print(string.format('requesting %d of %s', count, itemId))
  os.queueEvent('shop_provide', itemId, count, uid)
  local timerId = os.startTimer(5)
  while true do
    local e, p1, p2 = os.pullEvent()
    if e == 'timer' and p1 == timerId then
      print('timed out waiting for provide')
      refundTransaction(value, "error=Timed out attempting to provide items")
      break

    elseif e == 'shop_provided' and p1 == uid then
      local extra = value - (price * p2)
      if extra > 0 then
        print('extra: ' .. extra)
        refundTransaction(extra, "message=Here's your change!")
      end
      break
    end
  end
end

local function connect()
  print('opening store for: ' .. domain)

  local success, ws = await(k.connect, privatekey)
  assert(success, "Failed to get websocket URL")

  print("Connected to websocket.")
  rs.setOutput('top', true)

  success = await(ws.subscribe, "ownTransactions", function(data)
    local transaction = data.transaction
    handleTransaction(transaction)
  end)
  assert(success, "Failed to subscribe to event")
end

jua.go(function()
  print("Ready")
  connect()
end)
