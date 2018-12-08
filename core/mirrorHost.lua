_G.requireInjector()

local Event  = require('event')
local Logger = require('logger')
local Socket = require('socket')

local colors = _G.colors
local term   = _G.term

Logger.setScreenLogging()

local mon = term.current()
local args = { ... }
if args[1] then
  mon = _G.device[args[1]]
end

if not mon then
  error('Invalid monitor')
end

mon.setBackgroundColor(colors.black)
mon.clear()

while true do
  local socket = Socket.server(5901)

  print('mirror: connection from ' .. socket.dhost)

  Event.addRoutine(function()
    while true do
      local data = socket:read()
      if not data then
        break
      end
      for _,v in ipairs(data) do
        mon[v.f](unpack(v.args))
      end
    end
  end)

  while true do
    Event.pullEvent()
    if not socket.connected then
      break
    end
  end

  print('connection lost')

  socket:close()
end
