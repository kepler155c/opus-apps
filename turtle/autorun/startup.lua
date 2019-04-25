if not _G.turtle then
  return
end

-- update
if fs.exists('packages/turtle/autorun/gps.lua') then fs.delete('packages/turtle/autorun/gps.lua') end

local Config = require('config')
local GPS    = require('gps')
local Point  = require('point')
local Util   = require('util')

local device     = _G.device
local fs         = _G.fs
local peripheral = _G.peripheral
local turtle     = _G.turtle

-- add a System setup tab
fs.mount('sys/apps/system/turtle.lua', 'linkfs', 'packages/turtle/system/turtle.lua')

-- provide a turtle function for scanning
function turtle.scan(whitelist, blacklist)
  local pt = turtle.point

  local scanner = device['plethora:scanner'] or error('Scanner not equipped')

  if not whitelist and not blacklist then
    return Util.each(scanner.scan(), function(b)
      b.x = pt.x + b.x
      b.y = pt.y + b.y
      b.z = pt.z + b.z
    end)
  end

  if whitelist then
    return Util.filter(scanner.scan(), function(b)
      if whitelist[b.name] then
        b.x = pt.x + b.x
        b.y = pt.y + b.y
        b.z = pt.z + b.z
        return true
      end
    end)
  end

  return Util.filter(scanner.scan(), function(b)
    if not blacklist[b.name] then
      b.x = pt.x + b.x
      b.y = pt.y + b.y
      b.z = pt.z + b.z
      return true
    end
  end)
end

local function getHeading(apt)
	if not turtle then
		return
	end

	local heading = turtle.point.heading
	local bpt

	repeat
    if not turtle.inspect() and turtle.forward() then
      bpt = GPS.locate()
			break
		end
		turtle.turnRight()
  until turtle.getHeading() == heading

  if not bpt then
    repeat
      if not peripheral.getType('front') then
        turtle.dig()
        if turtle.forward() then
          bpt = GPS.locate()
          break
        end
      end
      turtle.turnRight()
    until turtle.point.heading == heading
  end

  if not bpt then
    return false
  end

  local turns = (turtle.point.heading - heading) % 4

  turtle.back()
  turtle.setHeading(heading)

	if apt.x < bpt.x then
		return (0 - turns) % 4
	elseif apt.z < bpt.z then
		return (1 - turns) % 4
	elseif apt.x > bpt.x then
		return (2 - turns) % 4
	end
	return (3 - turns) % 4
end

local function getScannedHeading()
	local facing = device['plethora:scanner'].getBlockMeta(0, 0, 0).state.facing
	return Point.facings[facing].heading
end

-- [[ GPS ]] --
function turtle.enableGPS(timeout)
	local pt = GPS.getPoint(timeout or 2) or error('GPS not found')

	if device['plethora:scanner'] then
		pt.heading = getScannedHeading()

	elseif turtle.select('plethora:module:2') then
		-- never swap out modem
		local equip = turtle.isEquipped('modem') == 'right' and turtle.equipLeft or turtle.equipRight

		if equip() then
			pt.heading = getScannedHeading()
			equip()
		end
	end

	if not pt.heading then
		pt.heading = getHeading(pt)
	end

	if pt.heading then
		turtle.setPoint(pt, true)
		return turtle.point
	end
end

-- return to home location if configured to do so
if _G.device.wireless_modem then
  local config = Config.load('gps')

  if config.home then
    if not turtle.enableGPS(2) then
      error('Unable to get GPS position')
    end

    if config.destructive then
      turtle.set({ attackPolicy = 'attack', digPolicy = 'turtleSafe' })
    end

    if not turtle.pathfind(config.home) then
      error('Failed to return home')
    end
  end
end
