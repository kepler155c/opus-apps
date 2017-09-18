requireInjector(getfenv(1))

local Event        = require('event')
local GPS          = require('gps')
local ChestAdapter = require('chestAdapter18')
local Point        = require('point')
local Socket       = require('socket')
local Util         = require('util')

if not device.wireless_modem then
  error('Modem is required')
end

if not turtle then
  error('Can only be run on a turtle')
end

local blocks = { }
local items = { }

local locations = Util.readTable('/usr/config/pickup') or {
  pickups = { },
  cells = { },
  refills = { },
  fluids = { },
}

local fuel = {
  item = {
    name = 'minecraft:coal',
    damage = 0,
  },
  qty = 64
}

local slots

turtle.setMoveCallback(function(action, pt)
  if slots then
    for _,slot in pairs(slots) do
      if turtle.getItemCount(slot.index) ~= slot.qty then
        printError('Slots changed')
        Event.exitPullEvents()
      end
    end
  end
end)

function refuel()
  if turtle.getFuelLevel() < 5000 and locations.dropPt then
    print('refueling')
    turtle.status = 'refueling'
    gotoPoint(locations.dropPt, true)
    dropOff(locations.dropPt)
    local chestAdapter = ChestAdapter({
        wrapSide = 'bottom',
        direction = 'up',
      })
    while turtle.getFuelLevel() < 5000 do
      turtle.select(1)
      chestAdapter:provide(fuel.item, fuel.qty, 1)
      turtle.refuel(64)
      print(turtle.getFuelLevel())
      os.sleep(1)
    end
  end
end

function pickUp(pt)
  turtle.status = 'picking up'
  gotoPoint(pt, true)
  while true do
    if not turtle.selectOpenSlot() then
      dropOff(locations.dropPt)
      gotoPoint(pt, true)
    end
    turtle.select(1)
    if not turtle.suckDown(64) then
      return
    end
  end
end

function dropOff(pt)
  if turtle.selectSlotWithItems() then
    gotoPoint(pt, true)
    turtle.emptyInventory(turtle.dropDown)
    if pt == locations.dropPt then
      print('refreshing items')
      chestAdapter = ChestAdapter()
      items = chestAdapter:refresh()
    end
  end
end

function gotoPoint(pt, doDetect)
  slots = turtle.getInventory()
  while not turtle.pathfind(pt, { blocks = blocks }) do
    if turtle.abort then
      error('aborted')
    end
    turtle.status = 'blocked'
    os.sleep(5)
  end

  if doDetect and not turtle.detectDown() then
    printError('Missing target')
    Event.exitPullEvents()
  end
end

function checkCell(pt)
  if not turtle.selectOpenSlot() then
    dropOff(locations.dropPt)
  end

  print('checking cell')
  turtle.status = 'recharging'
  gotoPoint(pt, true)
  local c = peripheral.wrap('bottom')
  local energy = c.getMaxEnergyStored() -
      c.getEnergyStored()
  if energy > 20000 then
    print('charging cell')
    turtle.selectOpenSlot()
    turtle.digDown()
    gotoPoint(locations.chargePt, true)
    turtle.dropDown()
    os.sleep(energy / 20000)
    turtle.suckDown()
    print('replacing cell')
    gotoPoint(pt)
    if not turtle.placeDown() then
      error('could not place down cell')
    end
  end
end

function fluid(points)
  print('checking fluid')
  turtle.status = 'fluiding'
  gotoPoint(points.source, true)
  turtle.select(1)
  turtle.digDown()
  gotoPoint(points.target)
  if not turtle.placeDown() then
    error('could not place fluid container')
  end
  os.sleep(5)
  turtle.digDown()
  gotoPoint(points.source)
  turtle.placeDown()
end

function refill(entry)
  dropOff(locations.dropPt)

  turtle.status = 'refilling'
  gotoPoint(locations.dropPt)
  local chestAdapter = ChestAdapter()
  for _,item in pairs(entry.items) do
    chestAdapter:provide(item, tonumber(item.qty), turtle.selectOpenSlot())
  end

  if turtle.selectSlotWithItems() then
    if entry.point then
      dropOff(entry.point)
    end
  end
end

function oldRefill(points)
  gotoPoint(points.source)
  repeat until not turtle.suckDown(64)
  if points.target then
    dropOff(points.target)
  end
  if points.targets then
    for k,target in pairs(points.targets) do
      dropOff(target)
    end
  end
  dropOff(points.source)
  dropOff(locations.dropPt)
end

local function makeKey(pt)
  return string.format('%d:%d:%d', pt.x, pt.y, pt.z)
end

local function pickupHost(socket)

  while true do
    local data = socket:read()
    if not data then
      print('pickup: closing connection to ' .. socket.dhost)
      return
    end

    print('command: ' .. data.type)
    
    if data.type == 'pickup' then
      local key = makeKey(data.point)
      locations.pickups[key] = data.point
      Util.writeTable('/usr/config/pickup', locations)
      socket:write( { type = "response", response = 'added' })

    elseif data.type == 'items' then
      socket:write( { type = "response", response = items })
    
    elseif data.type == 'refill' then
      local key = makeKey(data.entry.point)
      locations.refills[key] = data.entry
      Util.writeTable('/usr/config/pickup', locations)
      socket:write( { type = "response", response = 'added' })

    elseif data.type == 'setPickup' then
      locations.dropPt = data.point
      Util.writeTable('/usr/config/pickup', locations)
      socket:write( { type = "response", response = 'Location set' })

    elseif data.type == 'setRecharge' then
      locations.chargePt = data.point
      Util.writeTable('/usr/config/pickup', locations)
      socket:write( { type = "response", response = 'Location set' })
    
    elseif data.type == 'charge' then
      local key = makeKey(data.point)
      locations.cells[key] = data.point
      Util.writeTable('/usr/config/pickup', locations)
      socket:write( { type = "response", response = 'added' })
    
    elseif data.type == 'fluid' then

    elseif data.type == 'clear' then
      local key = makeKey(data.point)
      locations.refills[key] = nil
      locations.cells[key] = nil
      locations.fluids[key] = nil
      locations.pickups[key] = nil

      Util.writeTable('/usr/config/pickup', locations)
    
      socket:write( { type = "response", response = 'cleared' })
    else
      print('unknown command')
    end
  end
end

Event.addRoutine(function()
  while true do
    print('waiting for connection on port 5222')
    local socket = Socket.server(5222)

    print('pickup: connection from ' .. socket.dhost)

    Event.addRoutine(function() pickupHost(socket) end)
  end
end)

local function eachEntry(t, fn)

  local keys = Util.keys(t)
  for _,key in pairs(keys) do
    if t[key] then
      if turtle.abort then
        return
      end
      fn(t[key])
    end
  end
end

local function eachClosestEntry(t, fn)

  local points = { }
  for k,v in pairs(t) do
    v = Util.shallowCopy(v)
    v.key = k
    table.insert(points, v)
  end

  while not Util.empty(points) do
    local closest = Point.closest(turtle.point, points)
    if turtle.abort then
      return
    end
    if t[closest.key] then
      fn(closest)
    end
    for k,v in pairs(points) do
      if v.key == closest.key then
        table.remove(points, k)
        break
      end
    end
  end
end

Event.addRoutine(function()

  if not turtle.enableGPS() then
    error('turtle: No GPS found')
  end

  refuel()

  while true do
    if locations.dropPt then
      eachClosestEntry(locations.pickups, pickUp)
      eachEntry(locations.refills, refill)
      refuel()
    end
    dropOff(locations.dropPt)
    eachEntry(locations.fluids, fluid)
    if locations.chargePt then
      eachEntry(locations.cells, checkCell)
    end
    print('sleeping')
    turtle.status = 'sleeping'
    if turtle.abort then
      printError('aborted')
      break
    end
    os.sleep(60)
  end

  Event.exitPullEvents()
end)

turtle.run(function()

  Event.pullEvents()

end)
