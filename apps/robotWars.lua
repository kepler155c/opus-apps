local os         = _G.os
local peripheral = _G.peripheral

local ni = peripheral.find("neuralInterface")
if not ni then
	error("Cannot find neuralInterface")
end

local RADIUS = 6
local ROTATION = math.pi / 16
local args = { ... }

local TARGET = args[1] or error('Syntax: robotWars <targetName>')

local function yap(entity)
	local x, y, z = entity.x, entity.y + 1, entity.z
	local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
	local yaw = math.atan2(-(x - .5), z - .5)

  return math.deg(yaw), math.deg(pitch)
end

local function getUid()
  for _,v in pairs(ni.sense()) do
    if math.floor(v.x) == 0 and
       math.floor(v.z) == 0 then
      return v.id
    end
  end
  error('Could not find myself')
end

local uid = getUid()

local function findTarget(name)
  for _, v in pairs(ni.sense()) do
    if v.name == name and v.id ~= uid then
      return v
    end
  end
end

local function shootAt(name)
		local target = findTarget(name)
  if not target then
    return
  end
  local yaw, pitch = yap(target)
  debug('look: ' .. yaw)
  ni.look(yaw, pitch)
  debug('shoot')
  pcall(ni.shoot, 1)
end

while true do
	local target = findTarget(TARGET)
  if not target then
    print('Won??')
    break
  end
  local angle = math.atan2(-target.x, -target.z) + ROTATION
  debug('walk: ' .. angle)

  ni.walk(
    target.x + RADIUS * math.sin(angle),
    0,
    target.z + RADIUS * math.cos(angle))
  os.sleep(.2)
  repeat
    os.sleep(0)
  until not ni.isWalking()

  shootAt(TARGET)
end
