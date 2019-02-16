local GPS = require('gps')
local Util = require('util')

local device = _G.device
local turtle = _G.turtle

if device.neuralInterface and device.wireless_modem then
  local ni = require('neural.interface')
  device.neuralInterface.goTo = function(x, y, z)
    local pt = GPS.locate(2)
    if pt then
      return pcall(function()
        if false and device.neuralInterface.walk then
          local gpt = {
            x = x - pt.x,
            y = 0,
            z = z - pt.z,
          }
          gpt.x = math.min(math.max(gpt.x, -15), 15)
          gpt.z = math.min(math.max(gpt.z, -15), 15)
          return device.neuralInterface.walk(gpt.x, gpt.y, gpt.z)
        else
          local y, p = ni.yap(pt, { x = x, y = y + 3, z = z })
          ni.look(y, 0)
          return ni.launch(y, p, 1.5)
        end
      end)
    end
    return false, 'No GPS'
  end
end

if turtle then
  function turtle.scan(blocks)
    local pt = turtle.point
    local scanner = device['plethora:scanner'] or error('Scanner not equipped')

    if not blocks then
      return Util.each(scanner:scan(), function(b)
        b.x = pt.x + b.x
        b.y = pt.y + b.y
        b.z = pt.z + b.z
      end)
    end

    return Util.filter(scanner:scan(), function(b)
      if blocks[b.name] then
        b.x = pt.x + b.x
        b.y = pt.y + b.y
        b.z = pt.z + b.z
        return true
      end
    end)
  end
end
