local GPS = require('gps')

local device = _G.device

if device.neuralInterface and device.wireless_modem then
  local ni = require('neural.interface')
  device.neuralInterface.goTo = function(x, y, z)
    local pt = GPS.locate(2)
    if pt then
      return pcall(function()
        if device.neuralInterface.walk then
          local gpt = {
            x = x - pt.x,
            y = 0,
            z = z - pt.z,
          }
          gpt.x = math.min(math.max(gpt.x, -15), 15)
          gpt.z = math.min(math.max(gpt.z, -15), 15)
          return device.neuralInterface.walk(gpt.x, gpt.y, gpt.z, 2)
        elseif ni.launch then
          local y, p = ni.yap(pt, { x = x, y = y + 3, z = z })
          ni.look(y, 0)
          return ni.launch(y, p, 1.5)
        end
      end)
    end
    return false, 'No GPS'
  end
end

