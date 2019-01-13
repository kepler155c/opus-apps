local Event   = require('event')
local GPS     = require('gps')
local itemDB  = require('itemDB')
local Point   = require('point')
local Socket  = require('socket')
local sync    = require('sync').sync
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

local spt = GPS.getPoint() or error('GPS failure')
local blockTypes = { } -- blocks types requested to mine
local turtles    = { }
local rawBlocks  = { } -- scanner data
local queue      = { } -- actual blocks to mine
local abort

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Scan',   event = 'scan' },
			{ text = 'Totals', event = 'totals' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		columns = {
			{ heading = 'Name',  key = 'displayName' },
			{ heading = 'Count', key = 'count', width = 5, justify = 'right' },
		},
		sortColumn = 'displayName',
	},
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
  local pt
  sync(turtles, function()
    if #queue == 0 then
      queue = page:getBlocksToMine() or { }
    end
    pt = Point.closest(turtle.getPoint(), queue)
    Util.removeByValue(queue, pt)
  end)
  return pt
end

local function run(id)
  Event.addRoutine(function()
    local turtle = hijackTurtle(id)
    if turtle then
      turtles[id] = turtle

      turtle.resetState()
      turtle.enableGPS()
      turtle.setPolicy('turtleSafe')

      repeat
        local pt = getNextPoint(turtle)
        if pt then
          turtle.digAt(pt, pt.name)
        else
          os.sleep(1)
        end
      until abort
    end
    turtle._goto(spt)
    turtles[id] = nil
  end)
end

function page:getBlocksToMine()
  if Util.size(blockTypes) > 0 then
    self:scan()
    return Util.reduce(rawBlocks,
      function(acc, b)
        local key = table.concat({ b.name, b.metadata }, ':')
        if blockTypes[key] then
          table.insert(acc, b)
        end
      end, { })
  end
end

function page:scan()
  rawBlocks = scanner:scan()
  local gpt = GPS.getPoint() or error('GPS locate failed')

  self.grid:setValues(Util.reduce(rawBlocks,
    function(acc, b)
      local key = table.concat({ b.name, b.metadata }, ':')
      local entry = acc[key]
      if not entry then
        b.displayName = itemDB:getName(key)
        b.count = 1
        b.key = key
        acc[key] = b
			else
				entry.count = entry.count + 1
      end
      b.x = gpt.x + b.x
      b.y = gpt.y + b.y
      b.z = gpt.z + b.z
		end,
		{ }))

	self.grid:draw()
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
		self:scan()

  elseif event.type == 'grid_select' then
    blockTypes[self.grid:getSelected().key] = true
    self.grid:draw()
  end

	UI.Page.eventHandler(self, event)
end

Event.onInterval(1, function()
  if not abort then
    for k,v in pairs(network) do
      if v.active and v.distance and v.distance < 16 and not turtles[k] then
        turtles[k] = run(k)
      end
    end
  elseif Util.size(turtles) == 0 then
    Event.exitPullEvents()
  end
end)

page:scan()
UI:setPage(page)

Event.onTerminate(function()
  abort = true
  spt = GPS.getPoint()
end)

Event.pullEvents()
