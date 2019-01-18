local Event   = require('event')
local GPS     = require('gps')
local itemDB  = require('itemDB')
local Point   = require('point')
local Socket  = require('socket')
local Util    = require('util')
local UI      = require('ui')

local colors  = _G.colors
local device  = _G.device
local network = _G.network
local os      = _G.os

UI:configure('multiMiner', ...)

local scanner = device.neuralInterface
if not scanner or not scanner.scan then
	error('Plethora scanner must be equipped')
end

local function locate()
  for _ = 1, 3 do
    local pt = GPS.getPoint()
    if pt then
      return pt
    end
  end
end

local spt = GPS.getPoint() or error('GPS failure')
local chestPoint       -- location of chest
local blockTypes = { } -- blocks types requested to mine
local turtles    = { } -- active turtles
local pool       = { } -- all turtles
local queue      = { } -- actual blocks to mine
local abort

local function hijackTurtle(remoteId)
	local socket, msg = Socket.connect(remoteId, 188)

  if not socket then
    _G.printError(remoteId)
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

	return hijack
end

local function getNextPoint(turtle)
  local pt = Point.closest(turtle.getPoint(), queue)
  if pt then
    turtle.pt = pt
    queue[pt.pkey] = nil
    return pt
  end
end

local function run(member, point)
  Event.addRoutine(function()
    local _, m = pcall(function()
      member.active = true
      local turtle = hijackTurtle(member.id)

      local function emptySlots(retain, pt)
        local slots = turtle.getFilledSlots()
        for _,slot in pairs(slots) do
          if not retain[slot.key] then
            turtle.select(slot.index)
            turtle.dropAt(pt, 64)
          end
        end
      end

      local function dropOff()
        -- go to 2 above chest
        local topPoint = Point.copy(chestPoint)
        topPoint.y = topPoint.y + 2
        turtle.gotoY(topPoint.y)
        while not turtle._goto(topPoint) do
          os.sleep(.5)
        end

        -- path to chest
        local box = Point.makeBox(
          { x = chestPoint.x - 3, y = chestPoint.y + 3, z = chestPoint.z - 3 },
          { x = chestPoint.x + 3, y = chestPoint.y, z = chestPoint.z + 3 }
        )
        turtle.set({
          movementStrategy = 'pathing',
          pathingBox = Point.normalizeBox(box),
          digPolicy = 'digNone',
        })
        while not turtle.moveAgainst(chestPoint) do
          os.sleep(.5)
        end
        emptySlots({ }, chestPoint)

        -- path to 3 above chest
        turtle.pathfind(Point.above(topPoint))
        turtle.set({
          movementStrategy = 'goto',
          digPolicy = 'turtleSafe',
        })
      end

      if turtle then
        turtles[member.id] = turtle

        turtle.reset()
        turtle.set({
          attackPolicy = 'attack',
          digPolicy = 'turtleSafe',
          movementStrategy = 'goto',
          point = point,
        })

        repeat
          local pt = getNextPoint(turtle)
          if pt then
            member.status = 'digging'
            turtle.digAt(pt, pt.name)
            if turtle.getItemCount(15) > 0 then
              member.status = 'ejecting trash'
              emptySlots(blockTypes, Point.above(turtle.getPoint()))
              turtle.condense()
              if turtle.getItemCount(15) > 0 then
                member.status = 'dropping off'
                if not chestPoint then
                  member.abort = true
                  member.status = 'full'
                else
                  dropOff()
                end
              end
            end
          else
            member.status = 'waiting'
            os.sleep(1)
          end
          if member.fuel < 100 then
            member.status = 'out of fuel'
            break
          end
        until member.abort
      end

      emptySlots(blockTypes, Point.above(turtle.getPoint()))

      if chestPoint then
        dropOff()
        while not turtle._goto(Point.above(spt)) do
          os.sleep(.5)
        end
        turtle.set({ digPolicy = 'dig' })
        turtle._goto(spt)
      else
        turtle.gotoY(spt.y)
        turtle._goto(spt)
      end
    end)
    turtles[member.id] = nil
    member.status = m
    member.active = false
  end)
end

local blocksTab = UI.Window {
  tabTitle = 'Blocks',
  grid = UI.ScrollingGrid {
    y = 1,
    columns = {
      { heading = 'Name',  key = 'displayName' },
      { heading = 'Count', key = 'count', width = 5, justify = 'right' },
    },
    sortColumn = 'displayName',
  },
}

local turtlesTab = UI.Window {
  tabTitle = 'Turtles',
  grid = UI.ScrollingGrid {
    y = 1,
    values = pool,
    columns = {
      { heading = 'ID',   key = 'label', width = 12, },
      { heading = 'Fuel', key = 'fuel', width = 5, justify = 'right' },
      { heading = 'Status', key = 'status' },
    },
    sortColumn = 'label',
  },
}

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Scan',  event = 'scan' },
			{ text = 'Abort', event = 'abort' },
		},
  },
  tabs = UI.Tabs {
    y = 2, ey = -2,
    [1] = blocksTab,
    [2] = turtlesTab,
  },
  info = UI.Window {
    y = -1,
    backgroundColor = colors.gray,
  }
}

function page.info:draw()
  self:clear()
  self:write(2, 1, 'Turtles: ' .. Util.size(turtles))
  if not chestPoint then
    self:write(16, 1, 'No chest')
  end
  self:write(28, 1, 'Queue: ' .. Util.size(queue))
end

function page:scan()
  local gpt = GPS.getPoint()
  if not gpt then
    return
  end
  local rawBlocks = scanner:scan()
  local candidates = { }

  self.totals = Util.reduce(rawBlocks,
    function(acc, b)
      b.key = table.concat({ b.name, b.metadata }, ':')
      local entry = acc[b.key]
      if not entry then
        b.displayName = itemDB:getName(b.key)
        b.count = 1
        acc[b.key] = b
			else
        entry.count = entry.count + 1
      end

      if b.name == 'computercraft:turtle_advanced' or
         b.name == 'computercraft:turtle' then
        table.insert(candidates, b)
      end

      if b.name == 'minecraft:chest' then
        chestPoint = b
      end

      -- add relevant blocks to queue
      b.x = gpt.x + b.x
      b.y = gpt.y + b.y
      b.z = gpt.z + b.z
      b.pkey = table.concat({ b.x, b.y, b.z }, ':')
      if blockTypes[b.key] then
        if not Util.any(turtles, function(t)
              return t.pt and t.pt.pkey == b.pkey
            end) then
          queue[b.pkey] = b
        end
      else
        queue[b.pkey] = nil
      end
		end,
    { })

  for _, b in pairs(candidates) do
    local v = scanner.getBlockMeta(b.x - gpt.x, b.y - gpt.y, b.z - gpt.z)
    if v and v.computer then
      local member = pool[v.computer.id]
      if not member then
        member = {
          id = v.computer.id,
          label = v.computer.label,
        }
        pool[v.computer.id] = member
      end

      member.fuel = v.turtle.fuel
      member.distance = 0

      if not v.computer.isOn then
        member.status = 'Powered off'
      elseif v.turtle.fuel < 100 and not member.active then
        member.status = 'Not enough fuel'
      elseif not member.active and not member.abort then
        local pt = Point.copy(b)
        pt.heading = Point.facings[v.state.facing].heading
        run(member, pt)
      end
    end
  end
end

function blocksTab.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.count = Util.toBytes(row.count)
	return row
end

function blocksTab.grid:getRowTextColor(row, selected)
  return blockTypes[row.key] and
    colors.yellow or
    UI.Grid.getRowTextColor(self, row, selected)
end

function blocksTab:eventHandler(event)
	if event.type == 'grid_select' then
    local key = event.selected.key
    if blockTypes[key] then
      for k,v in pairs(queue) do
        if v.key == key then
          queue[k] = nil
        end
      end
      blockTypes[key] = nil
    else
      blockTypes[key] = true
    end
    self.grid:draw()
  end
end

function page:eventHandler(event)
  if event.type == 'scan' then
    blocksTab.grid:setValues(self.totals)
    blocksTab.grid:draw()
    self.tabs:selectTab(blocksTab)

  elseif event.type == 'abort' then
    for _, v in pairs(pool) do
      v.abort = true
      v.status = 'aborting'
    end
    spt = Point.above(locate())
    abort = true
  end

	UI.Page.eventHandler(self, event)
end

Event.onInterval(3, function()
  if not abort then
    page:scan()
  end
end)

Event.onInterval(1, function()
  if not abort then
    for id,v in pairs(network) do
      if v.fuel then
        if pool[id] then
          pool[id].fuel = v.fuel
          pool[id].distance = v.distance
        end
      end
    end
  elseif Util.size(turtles) == 0 then
    Event.exitPullEvents()
  end

  if turtlesTab.enabled then
    turtlesTab.grid:update()
    turtlesTab.grid:draw()
  end

  page.info:draw()
  page.info:sync()
end)

Event.onTimeout(.5, function()
  page:scan()
  blocksTab.grid:setValues(page.totals)
  page:sync()
end)

UI:setPage(page)

Event.onTerminate(function()
  spt = Point.above(locate())
  for _, v in pairs(pool) do
    v.status = 'aborting'
    v.abort = true
  end
  abort = true
end)

Event.pullEvents()
