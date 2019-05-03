local jua = nil
local idPatt = "#R%d+"

if not ((socket and socket.websocket) or http.websocketAsync) then
  error("You do not have CC:Tweaked/CCTweaks installed or you are not on the latest version.")
end

local newws = socket and socket.websocket or http.websocketAsync
local async
if socket and socket.websocket then
  async = false
else
  async = true
end

callbackRegistry = {}
wsRegistry = {}

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
  local id = tonumber(found[#found]:sub(found[#found]:find("%d+")))
  return id
end

local function newID()
  return #callbackRegistry + 1
end

local function trimID(url)
  local found = gfind(url, idPatt)
  local s, e = url:find(found[#found])
  return url:sub(1, s-1)
end

function open(callback, url, headers)
  local id
  if async then
    id = newID()
  end
  local newUrl
  if async then
    newUrl = url .. "#R" .. id
    newws(newUrl, headers)
  else
    if headers then
      error("Websocket headers not supported under CCTweaks")
    end
    local ws = newws(url)
    ws.send = ws.write
    id = ws.id()
    wsRegistry[id] = ws
  end
  callbackRegistry[id] = callback
  return id
end

function init(jua)
  jua = jua
  if async then
    jua.on("websocket_success", function(event, url, handle)
      local id = findID(url)
      if id and callbackRegistry[id] and callbackRegistry[id].success then
        callbackRegistry[id].success(id, handle)
      end
    end)

    jua.on("websocket_failure", function(event, url)
      local id = findID(url)
      if id and callbackRegistry[id] and callbackRegistry[id].failure then
        callbackRegistry[id].failure(id)
      end
      table.remove(callbackRegistry, id)
    end)

    jua.on("websocket_message", function(event, url, data)
      local id = findID(url)
      if id and callbackRegistry[id] and callbackRegistry[id].message then
        callbackRegistry[id].message(id, data)
      end
    end)

    jua.on("websocket_closed", function(event, url)
      local id = findID(url)
      if id and callbackRegistry[id] and callbackRegistry[id].closed then
        callbackRegistry[id].closed(id)
      end
      table.remove(callbackRegistry, id)
    end)
  else
    jua.on("socket_connect", function(event, id)
      if id and callbackRegistry[id] and callbackRegistry[id].success then
        callbackRegistry[id].success(id, wsRegistry[id])
      end
    end)

    jua.on("socket_error", function(event, id, msg)
      if id and callbackRegistry[id] and callbackRegistry[id].failure then
        callbackRegistry[id].failure(id, msg)
      end
      table.remove(callbackRegistry, id)
    end)

    jua.on("socket_message", function(event, id)
      if id and callbackRegistry[id] and callbackRegistry[id].message then
        local data = wsRegistry[id].read()
        callbackRegistry[id].message(id, data)
      end
    end)

    jua.on("socket_closed", function(event, id)
      if id and callbackRegistry[id] and callbackRegistry[id].closed then
        callbackRegistry[id].closed(id)
      end
      table.remove(callbackRegistry, id)
    end)
  end
end

return {
  open = open,
  init = init
}