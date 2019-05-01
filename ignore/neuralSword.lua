local ni   = require('neural.interface')
local Util = require('util')

local os = _G.os

while true do
  local target = Util.find(ni.sense(), 'name', '///////')
  if target then
    if math.abs(target.x) < 2 and
       math.abs(target.z) < 2 then
      ni.lookAt(target)
      ni.swing()
      os.sleep(.5)
    else
      local angle = math.atan2(-(target.x - .5), target.z - .5)
      ni.walkTo({
        x = target.x + 1.5 * math.sin(angle),
        y = 0,
        z = target.z - 1.5 * math.cos(angle)
      }, 1)
    end
  else
    print('no target')
    os.sleep(1)
  end
end