local jua = nil
local idPatt = "#R%d+"

callbackRegistry = {}

local function gfind(str, patt)
	local t = {}
	for found in str:gmatch(patt) do
		table.insert(t, found)
	end

	if #t > 0 then
		return t
	else
		return nil
	end
end

local function findID(url)
	local found = gfind(url, idPatt)
	if found then
		return tonumber(found[#found]:sub(found[#found]:find("%d+")))
	end
end

local function newID()
	return #callbackRegistry + 1
end

local function trimID(url)
	local found = gfind(url, idPatt)
	local s, e = url:find(found[#found])
	return url:sub(1, s-1)
end

function request(callback, url, headers, postData)
	local id = newID()
	local newUrl = url .. "#R" .. id
	http.request(newUrl, postData, headers)
	callbackRegistry[id] = callback
end

function init(jua)
	jua = jua
	jua.on("http_success", function(event, url, handle)
		local id = findID(url)
		if id and callbackRegistry[id] then
			callbackRegistry[id](true, trimID(url), handle)
			table.remove(callbackRegistry, id)
		end
	end)

	jua.on("http_failure", function(event, url, handle)
		local id = findID(url)
		if id and callbackRegistry[id] then
			callbackRegistry[id](false, trimID(url), handle)
			table.remove(callbackRegistry, id)
		end
	end)
end

return {
	request = request,
	init = init
}