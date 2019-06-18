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
	motd = "motd"
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

local g = string.gsub
sha256 = loadstring(g(g(g(g(g(g(g(g('Sa=XbandSb=XbxWSc=XlshiftSd=unpackSe=2^32SYf(g,h)Si=g/2^hSj=i%1Ui-j+j*eVSYk(l,m)Sn=l/2^mUn-n%1VSo={0x6a09e667Tbb67ae85T3c6ef372Ta54ff53aT510e527fT9b05688cT1f83d9abT5be0cd19}Sp={0x428a2f98T71374491Tb5c0fbcfTe9b5dba5T3956c25bT59f111f1T923f82a4Tab1c5ed5Td807aa98T12835b01T243185beT550c7dc3T72be5d74T80deb1feT9bdc06a7Tc19bf174Te49b69c1Tefbe4786T0fc19dc6T240ca1ccT2de92c6fT4a7484aaT5cb0a9dcT76f988daT983e5152Ta831c66dTb00327c8Tbf597fc7Tc6e00bf3Td5a79147T06ca6351T14292967T27b70a85T2e1b2138T4d2c6dfcT53380d13T650a7354T766a0abbT81c2c92eT92722c85Ta2bfe8a1Ta81a664bTc24b8b70Tc76c51a3Td192e819Td6990624Tf40e3585T106aa070T19a4c116T1e376c08T2748774cT34b0bcb5T391c0cb3T4ed8aa4aT5b9cca4fT682e6ff3T748f82eeT78a5636fT84c87814T8cc70208T90befffaTa4506cebTbef9a3f7Tc67178f2}SYq(r,q)if e-1-r[1]<q then r[2]=r[2]+1;r[1]=q-(e-1-r[1])-1 else r[1]=r[1]+qVUrVSYs(t)Su=#t;t[#t+1]=0x80;while#t%64~=56Zt[#t+1]=0VSv=q({0,0},u*8)fWw=2,1,-1Zt[#t+1]=a(k(a(v[w]TFF000000),24)TFF)t[#t+1]=a(k(a(v[w]TFF0000),16)TFF)t[#t+1]=a(k(a(v[w]TFF00),8)TFF)t[#t+1]=a(v[w]TFF)VUtVSYx(y,w)Uc(y[w]W0,24)+c(y[w+1]W0,16)+c(y[w+2]W0,8)+(y[w+3]W0)VSYz(t,w,A)SB={}fWC=1,16ZB[C]=x(t,w+(C-1)*4)VfWC=17,64ZSD=B[C-15]SE=b(b(f(B[C-15],7),f(B[C-15],18)),k(B[C-15],3))SF=b(b(f(B[C-2],17),f(B[C-2],19)),k(B[C-2],10))B[C]=(B[C-16]+E+B[C-7]+F)%eVSG,h,H,I,J,j,K,L=d(A)fWC=1,64ZSM=b(b(f(J,6),f(J,11)),f(J,25))SN=b(a(J,j),a(Xbnot(J),K))SO=(L+M+N+p[C]+B[C])%eSP=b(b(f(G,2),f(G,13)),f(G,22))SQ=b(b(a(G,h),a(G,H)),a(h,H))SR=(P+Q)%e;L,K,j,J,I,H,h,G=K,j,J,(I+O)%e,H,h,G,(O+R)%eVA[1]=(A[1]+G)%e;A[2]=(A[2]+h)%e;A[3]=(A[3]+H)%e;A[4]=(A[4]+I)%e;A[5]=(A[5]+J)%e;A[6]=(A[6]+j)%e;A[7]=(A[7]+K)%e;A[8]=(A[8]+L)%eUAVUY(t)t=t W""t=type(t)=="string"and{t:byte(1,-1)}Wt;t=s(t)SA={d(o)}fWw=1,#t,64ZA=z(t,w,A)VU("%08x"):rep(8):format(d(A))V',"S"," local "),"T",",0x"),"U"," return "),"V"," end "),"W","or "),"X","bit32."),"Y","function "),"Z"," do "))()

function makeaddressbyte(byte)
	local byte = 48 + math.floor(byte / 7)
	return string.char(byte + 39 > 122 and 101 or byte > 57 and byte + 39 or byte)
end

function makev2address(key)
	local protein = {}
	local stick = sha256(sha256(key))
	local n = 0
	local link = 0
	local v2 = "k"
	repeat
		if n < 9 then protein[n] = string.sub(stick,0,2)
		stick = sha256(sha256(stick)) end
		n = n + 1
	until n == 9
	n = 0
	repeat
		link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
		if string.len(protein[link]) ~= 0 then
			v2 = v2 .. makeaddressbyte(tonumber(protein[link],16))
			protein[link] = ''
			n = n + 1
		else
			stick = sha256(stick)
		end
	until n == 9
	return v2
end

function toKristWalletFormat(passphrase)
	return sha256("KRISTWALLET"..passphrase).."-000"
end

return {
	init = init,
	address = address,
	addressTransactions = addressTransactions,
	addressNames = addressNames,
	addresses = addresses,
	rich = rich,
	transactions = transactions,
	latestTransactions = latestTransactions,
	transaction = transaction,
	makeTransaction = makeTransaction,
	connect = connect,
	parseMeta = parseMeta,
	sha256 = sha256,
	makeaddressbyte = makeaddressbyte,
	makev2address = makev2address,
	toKristWalletFormat = toKristWalletFormat
}