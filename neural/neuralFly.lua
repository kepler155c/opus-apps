_G.requireInjector(_ENV)

local Config = require('config')
local GPS = require('gps')
local ni = _G.device.neuralInterface

local os       = _G.os
local parallel = _G.parallel

local id = ni.getID()
local config = Config.load('flight', { })

local args = { ... }
if args[1] == 'wp' then
  local pt = GPS.locate()
  config[args[2]] = pt
  Config.update('flight', config)
  return
end

local wp = config[args[1]]
if not wp then
  error('invalid wp')
end

local pt = GPS.locate()

local function descend()
  print('descending to ' .. wp.y)
  repeat
    local meta = ni.getMetaByID(id)
    if meta.motionY < 0 then
      ni.launch(0, -90, math.min(4, meta.motionY / -0.5))
    end
    print(math.abs(wp.y - pt.y))
  until math.abs(wp.y - pt.y) < 1
end

local function gps()
  while true do
    local lpt = GPS.locate()
    if lpt then
      pt = lpt
    end
    os.sleep(.1)
  end
end

local function yap(x, y, z)
  local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
  local yaw = math.atan2(-(x - .5), z - .5)

  return math.deg(yaw), math.deg(pitch)
end

local function distance(a, b)
 return math.sqrt(
           math.pow(a.x - b.x, 2) +
           math.pow(a.z - b.z, 2))
end

local function hover()
  repeat
    local meta = ni.getMetaByID(id)
    local pitch = 295
    local yaw = yap(wp.x - pt.x, wp.y, wp.z - pt.z)

    if pt.y < wp.y + 16 and meta.motionY < 0 then
      ni.launch(yaw, pitch, math.min(4, math.min(4, -meta.motionY * math.abs(pt.y - (wp.y + 16)) / 2)))
    end

  until distance(wp, pt) < 2
end

local function launch()
  ni.launch(0, 270, 3)

  repeat
    local meta = ni.getMetaByID(id)
  until meta.motionY < 0

  hover()

  descend()
end

local s, m = pcall(parallel.waitForAny, launch, gps)

if not s then
  _G.printError(m)
end

--s, m = pcall(parallel.waitForAny, descend, gps)

if not s then
  error(m)
end
