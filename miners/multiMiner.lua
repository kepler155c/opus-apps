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
local blockTypes = { } -- blocks types requested to mine
local turtles    = { }
local queue      = { } -- actual blocks to mine
local abort

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Scan',  event = 'scan' },
			{ text = 'Abort', event = 'abort' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2, ey = -4,
		columns = {
			{ heading = 'Name',  key = 'displayName' },
			{ heading = 'Count', key = 'count', width = 5, justify = 'right' },
		},
		sortColumn = 'displayName',
  },
  info = UI.Window {
    y = -3,
  }
}

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
				error('timed out')
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

local function run(id)
  Event.addRoutine(function()
    local turtle = hijackTurtle(id)

    if turtle.getFuelLevel(id) < 100 then
      return
    end

    local function emptySlots(retain)
      local slots = turtle.getFilledSlots()
      for _,slot in pairs(slots) do
        if not retain[slot.key] then
          turtle.select(slot.index)
          turtle.dropUp(64)
        end
      end
    end

    local function enableGPS()
      for _ = 1, 3 do
        if turtle.enableGPS() then
          return
        end
      end
      error('GPS locate failed')
    end

    if turtle then
      turtles[id] = turtle

      turtle.resetState()
      enableGPS()
      turtle.setPolicy('turtleSafe')
      turtle.setMovementStrategy('goto')

      repeat
        local pt = getNextPoint(turtle)
        if pt then
          turtle.digAt(pt, pt.name)
        else
          os.sleep(1)
        end
        if turtle.getItemCount(15) > 0 then
          emptySlots(blockTypes)
          turtle.condense()
        end
        if turtle.getItemCount(15) > 0 then
          turtle._goto(spt)
          emptySlots({ })
        end
        if turtle.getFuelLevel() < 100 then
          turtle._goto(spt)
          emptySlots({ })
          break
        end
      until abort
    end
    turtle._goto(spt)
    turtles[id] = nil
  end)
end

function page.info:draw()
  self:clear()
  self:write(2, 1, 'Turtles: ' .. Util.size(turtles))
  self:write(2, 2, 'Queue:   ' .. Util.size(queue))
end

function page:scan()
  local gpt = GPS.getPoint()
  if not gpt then
    _debug('gps failed')
    return
  end
  local rawBlocks = scanner:scan()

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
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.count = Util.toBytes(row.count)
	return row
end

function page.grid:getRowTextColor(row, selected)
  return blockTypes[row.key] and
    colors.yellow or
    UI.Grid.getRowTextColor(self, row, selected)
end

function page:eventHandler(event)
	if event.type == 'scan' then
    self.grid:setValues(self.totals)
    self.grid:draw()

  elseif event.type == 'abort' then
    spt = Point.above(locate())
    abort = true
  
  elseif event.type == 'grid_select' then
    local key = self.grid:getSelected().key
    if blockTypes[key] then
      for k,v in pairs(queue) do
        if v.key == key then
          queue[k] = nil
        end
      end
      blockTypes[key] = nil
    else
      blockTypes[self.grid:getSelected().key] = true
    end
    self.grid:draw()
  end

	UI.Page.eventHandler(self, event)
end

Event.onInterval(3, function()
  page:scan()
end)

Event.onInterval(1, function()
  if not abort then
    for k,v in pairs(network) do
      if v.active and v.distance and v.distance < 16 and
        not turtles[k] and v.fuel and v.fuel > 100 then
        turtles[k] = run(k)
      elseif not v.active and turtles[k] then
        turtles[k] = nil
      end
    end
  elseif Util.size(turtles) == 0 then
    Event.exitPullEvents()
  end
  page.info:draw()
  page.info:sync()
end)

page:scan()
page.grid:setValues(page.totals)

UI:setPage(page)

Event.onTerminate(function()
  spt = Point.above(locate())
  abort = true
end)

Event.pullEvents()
