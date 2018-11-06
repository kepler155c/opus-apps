_G.requireInjector(_ENV)

local GPS = require('gps')

local device = _G.device

if device.neuralInterface and device.wireless_modem then
  device.neuralInterface.goTo = function(x, _, z)
    local pt = GPS.locate(2)
    if pt then
      return pcall(function()
        local gpt = {
          x = x - pt.x,
          y = 0,
          z = z - pt.z,
        }
        gpt.x = math.min(math.max(gpt.x, -15), 15)
        gpt.z = math.min(math.max(gpt.z, -15), 15)
        return device.neuralInterface.walk(gpt.x, gpt.y, gpt.z)
      end)
    end
    return false, 'No GPS'
  end
end
