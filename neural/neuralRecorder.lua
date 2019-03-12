local GPS  = require('gps')
local Point = require('point')
local Util = require('util')

local os         = _G.os
local parallel   = _G.parallel
local peripheral = _G.peripheral

local t = { }
local ni =
  peripheral.find('neuralInterface') or
  error('Neural Interface not found')

if not ni.getID then
  error('Missing Introspection Module')
end

local uid = ni.getID()
local c = os.clock()

local pt = GPS.locate(3) or error('GPS failed')
local lpt
local me = Util.find(ni.sense(), 'id', uid)

local function gps()
  while true do
    me = Util.find(ni.sense(), 'id', uid)
    pt = GPS.locate(3) or error('GPS failed')
    os.sleep(.3)
    print('got gps')
  end
end

local function record()
  local timerId = os.startTimer(.1)
  repeat
    local event, ch = os.pullEvent()
    local v
    local delay = os.clock() - c
    c = os.clock()
  --print(event .. ' ' .. tostring(ch))
    if event == 'char' then
  print('char ' .. ch)
      if ch == ' ' then
        v = {
          action = 'walk',
          x = pt.x,
          y = pt.y,
          z = pt.z,
          pitch = me.pitch,
          yaw = me.yaw,
          delay = delay,
        }
      elseif ch == 'u' then
        v = {
          action = 'use',
          x = pt.x,
          y = pt.y,
          z = pt.z,
          pitch = me.pitch,
          yaw = me.yaw,
          delay = delay,
        }
      end
    elseif event == 'timer' and ch == timerId then
      if not lpt or not Point.same(pt, lpt) then
        v = {
          action = 'walk',
          x = pt.x,
          y = pt.y,
          z = pt.z,
          pitch = me.pitch,
          yaw = me.yaw,
          delay = delay,
        }
        lpt = pt
      end
      timerId = os.startTimer(.2)
    end

    if v then
      Util.print(v)
      table.insert(t, v)
    end
  until event == 'char' and ch == 'q'
end

parallel.waitForAny(gps, record)
Util.writeTable('neural.tbl', t)
