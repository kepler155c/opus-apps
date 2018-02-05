_G.requireInjector(_ENV)

local GPS = require('gps')
local Util = require('util')
local Peripheral = require('peripheral')
local Point = require('point')

local p = Peripheral.lookup('594://name/neuralInterface')

_G._p = p
if not p then
  error('failed to connect')
end

local lpt = nil

while true do
  local pt = GPS.locate(2)

  if not pt then
    print('No GPS')
  else
    local gpt = Util.shallowCopy(pt)
    if pt and lpt and Point.same(pt, lpt) then
      -- havent moved
      print('no move')
    else
      if not lpt then
        gpt.x = gpt.x - 2
      else
        local dx = lpt.x - pt.x
        local dz = lpt.z - pt.z
        local angle = math.atan2(dx, dz)
        gpt.x = pt.x + 2.5 * math.sin(angle)
        gpt.z = pt.z + 2.5 * math.cos(angle)
      end
      lpt = pt
      local s, m = p.goTo(gpt.x, gpt.y + 1, gpt.z)
      if not s then
        print(m)
      end
    end
  end
  
  os.sleep(.5)
end