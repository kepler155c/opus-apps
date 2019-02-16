
local Event   = require('event')
local GPS     = require('gps')
local Point   = require('point')
local Socket  = require('socket')
local Util    = require('util')

local device  = _G.device
local os      = _G.os

local gpt = GPS.getPoint() or error('GPS not found')
local scanner = device.neuralInterface
if not scanner or not scanner.scan then
	error('Plethora scanner must be equipped')
end

local paused, abort
local chunkIndex = 0
local pool = { }
local blocks = Util.transpose({
  'minecraft:chest', 'minecraft:mob_spawner', 'minecraft:mossy_cobblestone'
})
local locations = { }

local function getLocations()
  local y = gpt.y - 8
  while y > 5 do
    table.insert(locations, y)
    y = y - 16
  end
  if y > 0 then
    table.insert(locations, 5)
  end
end

getLocations()
for _, v in pairs(locations) do
  print(v)
end

for _, b in pairs(scanner.scan()) do
  if b.name == 'computercraft:turtle_advanced' or
     b.name == 'computercraft:turtle' then

     local pt = {
       x = gpt.x + b.x,
       y = gpt.y + b.y,
       z = gpt.z + b.z,
    }
    local v = scanner.getBlockMeta(b.x, b.y, b.z)
    if v and v.computer then
      if not v.computer.isOn then
        print('Powered off: ' .. v.computer.id)
      elseif v.turtle.fuel < 100 then
        print('not enough fuel: ' .. v.computer.id)
      else
        pt.heading = Point.facings[v.state.facing].heading

        pool[v.computer.id] = {
          id = v.computer.id,
          label = v.computer.label,
          fuel = v.turtle.fuel,
          distance = 0,
          point = pt,
        }
      end
    end
  end
end

local function hijackTurtle(remoteId)
	local socket, msg = Socket.connect(remoteId, 188)

  if not socket then
		error(msg)
	end

	socket:write('turtle')
	local methods = socket:read()

	local hijack = { }
	for _,method in pairs(methods) do
		hijack[method] = function(...)
			socket:write({ fn = method, args = { ... } })
			local resp = socket:read()
			if not resp then
				error('timed out: ' .. method)
			end
			return table.unpack(resp)
		end
	end

	return hijack, socket
end

local function getNextPoint()
  local z = math.floor(chunkIndex / 3)
  local x = chunkIndex % 3

  chunkIndex = chunkIndex + 1

  while paused do
    os.sleep(3)
  end

  return { x = gpt.x + (x * 16), y = gpt.y, z = gpt.z + (z * 16) }
end

local function run(member)
  Event.addRoutine(function()
    local turtle, socket
    local _, m = pcall(function()
      member.active = true
      turtle, socket = hijackTurtle(member.id)

      if turtle then
        if not turtle.has('plethora:module:2') then
          error('missing scanner')
        end
        turtle.reset()
        turtle.set({
          attackPolicy = 'attack',
          digPolicy = 'turtleSafe',
          movementStrategy = 'goto',
          point = member.point,
        })
        turtle.select(1)

        repeat
          local pt = getNextPoint(turtle)
          if pt then
            member.status = 'digging'

            repeat until turtle._goto(pt)

            for _, v in ipairs(locations) do
              if abort then
                break
              end
              turtle.gotoY(v)
              turtle.equip('left', 'plethora:module:2')
              local found = turtle.scan(blocks)
              turtle.equip('left', 'minecraft:diamond_pickaxe')
              if Util.size(found) > 0 then
                paused = true
                print('found spawner')
                local b = next(found)
                print(string.format('%s:%s:%s'), b.x, b.y, b.z)
                print('press r to continue')
              end
            end
            turtle.gotoY(gpt.y)
          end

          if member.fuel < 100 then
            member.status = 'out of fuel'
            break
          end
        until abort
      end

      repeat until turtle.gotoY(gpt.y)
    end)

    if m then
      _G.printError(m)
    end

    pool[member.id] = nil
    print('Turtles: ' .. Util.size(pool))
    if Util.size(pool) == 0 then
      Event.exitPullEvents()
    end

    if socket then
      socket:close()
    end
  end)
end

print('press a to abort, r to resume')
Event.on('char', function(_, k)
  if k == 'r' then
    print('Resuming')
    paused = false
  elseif k == 'a' then
    print('Aborting')
    abort = true
  end
end)

Util.print('Found %s turtles', Util.size(pool))
Util.each(pool, function(member)
  run(member)
end)

Event.pullEvents()
