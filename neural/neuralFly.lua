_G.requireInjector(_ENV)

local ni = require('neural.interface')
local GPS = require('gps')

local strength = .315
local delay = .1

while ni.getMetaOwner().health < 26 do
  print('health: ' .. ni.getMetaOwner().health)
  os.sleep(1)
end

ni.launch(0, 270, 1.5)
os.sleep(.25)

local pt

local function fly()
  for i = 1, 100 do
    os.sleep(1)
    if pt then
      print(pt.y)
      print(strength)
    end
  end
end

local function gps()
  local lastY = 12
  while true do
    pt = GPS.locate()
    if pt then
      local d = math.abs(lastY - pt.y)

      -- force required to get to lvl 12

      local motionY = ni.getMetaOwner().motionY
--      print('y: ' .. pt.y)
      if pt.y < 12 then
        if pt.y > lastY then
          --strength = strength + .001
        else
          strength = strength + .02 * d
        end
      elseif pt.y > 12 then
        if pt.y > lastY then
          strength = strength - .02 * d
        else
          --strength = strength - .001
        end
      end
      lastY = pt.y
      
      -- force required to offset motion
      local om = (motionY - 0.138) / 0.8

  ni.launch(0, 270, strength-motionY)
--      print('strength: ' .. strength)
    os.sleep(delay)
    end
  end
end

parallel.waitForAny(fly, gps)

repeat
  ni.launch(0, 270, .25)
  os.sleep(.1)
until not ni.getMetaOwner().isAirborne

print('descending')
for i = 1, 50 do
  ni.launch(0, 270, .2)
  os.sleep(.1)
end

ni.look(180, 0)
