
local Event   = require('event')
local GPS     = require('gps')
local Point   = require('point')
local Socket  = require('socket')
local Sound   = require('sound')
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
  'minecraft:chest',
--  'minecraft:mob_spawner',
  'quark:crystal',
  'minecraft:mossy_cobblestone'
})
local locations = { }

gpt.x = gpt.x + 1

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

for _, b in pairs(scanner.scan()) do
  if b.name == 'computercraft:turtle_advanced' or
     b.name == 'computercraft:turtle' then

    local v = scanner.getBlockMeta(b.x, b.y, b.z)
    if v and v.computer then
      if not v.computer.isOn then
        print('Powered off: ' .. v.computer.id)
      elseif v.turtle.fuel < 100 then
        print('not enough fuel: ' .. v.computer.id)
      else
        pool[v.computer.id] = {
          id = v.computer.id,
          point = {
            x = gpt.x + b.x,
            y = gpt.y + b.y,
            z = gpt.z + b.z,
            heading = Point.facings[v.state.facing].heading,
          },
          index = Util.size(pool),
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

local function getNextPoint(member)
  local z = math.floor(chunkIndex / 3)
  local x = chunkIndex % 3

  chunkIndex = chunkIndex + 1

  while paused do
    os.sleep(3)
  end

  return {
    x = gpt.x + (x * 16),
    y = gpt.y + member.index,
    z = gpt.z + (z * 16) }
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
          local pt = getNextPoint(member)
          if pt then
            turtle.gotoY(pt.y)
            repeat until turtle._goto(pt)

            for _, v in ipairs(locations) do
              if abort then
                break
              end
              turtle.gotoY(v)
              turtle.equip('right', 'plethora:module:2')
              local found = turtle.scan(blocks)
              turtle.equip('right', 'minecraft:diamond_pickaxe')
              if Util.size(found) > 0 then
                paused = true
                print('found spawner')
                local _, b = next(found)
                print(string.format('%s:%s:%s', b.x, b.y, b.z))
                print('press r to continue')
                for _ = 1, 3 do
                  Sound.play('block.note.pling')
                  os.sleep(.3)
                 end
              end
            end
            turtle.gotoY(pt.y)
          end
        until abort

        turtle.gotoY(gpt.y + member.index)
        turtle._goto({ x = gpt.x, y = gpt.y + member.index, z = gpt.z })
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
    gpt = GPS.getPoint()
    print('Aborting')
    abort = true
  end
end)

Util.print('Found %s turtles', Util.size(pool))
Util.each(pool, function(member)
  run(member)
end)

Event.pullEvents()
