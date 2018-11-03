rednet.open("right")
local sensor = peripheral.wrap("back")
local modules = peripheral.wrap("back")
local Ka = peripheral.find("neuralInterface")
local function fire(entity)
  local x, y, z = entity.x, entity.y, entity.z
  local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
  local yaw = math.atan2(-x, z)

  Ka.look(math.deg(yaw), math.deg(pitch), 5)
  Ka.shoot(1)
  sleep(0.2)
end
local mobNames = {"Skeleton"}
local mobLookup = {}
for i = 1, #mobNames do
  mobLookup[mobNames[i]] = true
end

function SkeletonShoot()
  local mobs = sensor.sense()
  local candidates = {}
  for i = 1, #mobs do
    local mob = mobs[i]
    if mobLookup[mob.name] then
      candidates[#candidates + 1] = mob
    end
  end
  if #candidates > 0 then
    local mob = candidates[math.random(1, #candidates)]
    fire(mob)
  else
    sleep(.1)
  end
end

  while true do
      local id,message = rednet.receive()
        print(tostring(id)..message)
        if id == 582 then
          if message == "forward" then --W
              Ka.walk(1,0,0)
          elseif message == "back" then --S
              Ka.walk(-1,0,0)
          elseif message == "turnLeft" then--A
              Ka.walk(0,0,-1)
          elseif message == "turnRight" then--D
              Ka.walk(0,0,1)
          elseif message == "shoot" then--Starts fell program
              SkeletonShoot()
          end
        else
          write(" Denied!")
        end
      end

