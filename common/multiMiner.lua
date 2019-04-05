local Event   = require('event')
local GPS     = require('gps')
local itemDB  = require('core.itemDB')
local Point   = require('point')
local Socket  = require('socket')
local Util    = require('util')
local UI      = require('ui')

local colors  = _G.colors
local device  = _G.device
local gps     = _G.gps
local network = _G.network
local os      = _G.os

UI:configure('multiMiner', ...)

local glasses = device['plethora:glasses']
local scanner = device['plethora:scanner'] or
	error('Plethora scanner must be equipped')

-- hud
local canvas = glasses and glasses.canvas()
if canvas then
  canvas.group = canvas.addGroup({ 4, 90 })
  canvas.bg = canvas.group.addRectangle(0, 0, 60, 24, 0x00000033)
  canvas.text = canvas.group.addText({ 4, 5 }, '') -- , 0x202020FF)
  canvas.text.setShadow(true)
  canvas.text.setScale(.75)
end

-- container
local canvas3d = glasses and glasses.canvas3d().create()
local box, offset

local paused = false

local function inBox(pt)
  if not box or not box.ex then
    return true
  end
  return Point.inBox(pt, box)
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
		error(msg)
	end

	socket:write('turtle')
	local methods = socket:read()

	local hijack = { }
	for _,method in pairs(methods) do
		hijack[method] = function(...)
			socket:write({ method, ... })
			local resp = socket:read()
			if not resp then
				error('timed out: ' .. method)
			end
			return table.unpack(resp)
		end
	end

	return hijack, socket
end

local function getNextPoint(turtle)
  if not paused then
    local pt = Point.closest(turtle.getPoint(), queue)
    if pt then
      turtle.pt = pt
      queue[pt.pkey] = nil
      return pt
    end
  end
end

local function run(member, point)
  Event.addRoutine(function()
    local turtle, socket
    local _, m = pcall(function()
      member.active = true
      turtle, socket = hijackTurtle(member.id)

      local function emptySlots(retain, pt)
        local slots = turtle.getFilledSlots()
        for _,slot in pairs(slots) do
          if not retain[slot.key] then
            turtle.select(slot.index)
            if pt then
              turtle.dropAt(pt, 64)
            else
              turtle.dropUp(64)
            end
          end
        end
      end

      local function dropOff()
        -- go to 2 above chest
        local topPoint = Point.copy(chestPoint)
        topPoint.y = topPoint.y + 2
        turtle.gotoY(topPoint.y)
        while not turtle.go(topPoint) do
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
        turtle.select(1)

        repeat
          local pt = getNextPoint(turtle)
          if pt then
            member.status = 'digging'

            if blockTypes[pt.key] == true then
              if turtle.moveAgainst(pt) then
                local index = turtle.selectOpenSlot()
                if turtle.digAt(pt, pt.name) then
                  local slot = turtle.getSlot(index)
                  if slot.count > 0 then
                    blockTypes[pt.key] = slot.key
                    if slot.key ~= pt.key then
                      blockTypes[slot.key] = true
                    end
                  end
                end
              end
              turtle.select(1)
            else
              turtle.digAt(pt, pt.name)
            end

            if turtle.getItemCount(15) > 0 then
              member.status = 'ejecting trash'
              emptySlots(blockTypes)
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
              turtle.select(1)
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

      emptySlots(blockTypes)

      if chestPoint then
        dropOff()
        while not turtle.go(Point.above(spt)) do
          os.sleep(.5)
        end
        turtle.set({ digPolicy = 'dig' })
        turtle.go(spt)
      else
        turtle.gotoY(spt.y)
        turtle.go(spt)
      end
    end)

    turtles[member.id] = nil
    member.status = m
    member.active = false
    if socket then
      socket:close()
    end
  end)
end

local function drawContainer(pos)
  if canvas3d then
    canvas3d.clear()

    local function addBox(b)
      canvas3d.addBox(
        b.x - offset.x + .25,
        b.y - offset.y + .25 ,
        b.z - offset.z + .25 ,
        .5, .5, .5).setDepthTested(false)
    end
    if box and box.ex then
      addBox({ x = box.x,  y = box.y,  z = box.z  })
      addBox({ x = box.x,  y = box.y,  z = box.ez })
      addBox({ x = box.ex, y = box.y,  z = box.z  })
      addBox({ x = box.ex, y = box.y,  z = box.ez })
      addBox({ x = box.x,  y = box.ey, z = box.z  })
      addBox({ x = box.x,  y = box.ey, z = box.ez })
      addBox({ x = box.ex, y = box.ey, z = box.z  })
      addBox({ x = box.ex, y = box.ey, z = box.ez })
    elseif box then
      canvas3d.recenter({ -(pos.x % 1), -(pos.y % 1), -(pos.z % 1) })
      addBox(box)
    end
  end
end

local pauseResume = {
  { text = 'Pause', event = 'pause' },
  { text = 'Resume', event = 'resume' },
}
local containerText = {
  [[Set a corner to contain mining area]],
  [[Set ending corner]],
  [[Set again to clear]],
}

local containTab = UI.Tab {
  tabTitle = 'Contain',
  button = UI.Button {
    x = 2, y = 2,
    text = 'Set corner',
    event = 'contain'
  },
  textArea = UI.TextArea {
    x = 2, y = 4,
    value = containerText[1],
  },
}

local blocksTab = UI.Tab {
  tabTitle = 'Blocks',
  grid = UI.ScrollingGrid {
    y = 1,
    columns = {
      { heading = 'Count', key = 'count', width = 6, align = 'right' },
      { heading = 'Name',  key = 'displayName' },
    },
    sortColumn = 'displayName',
  },
}

local turtlesTab = UI.Tab {
  tabTitle = 'Turtles',
  grid = UI.ScrollingGrid {
    y = 1,
    values = pool,
    columns = {
      { heading = 'ID',     key = 'id',       width = 4, },
      { heading = ' Fuel',  key = 'fuel',     width = 5, align = 'right' },
      { heading = ' Dist',  key = 'distance', width = 5, align = 'right' },
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
			pauseResume[1],
		},
  },
  tabs = UI.Tabs {
    y = 2, ey = -2,
    [1] = blocksTab,
    [2] = turtlesTab,
    [3] = containTab,
  },
  info = UI.Window {
    y = -1,
    backgroundColor = colors.blue,
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

function turtlesTab.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
  row.distance = row.distance and Util.round(row.distance, 1)
  row.fuel = row.fuel and row.fuel > 0 and Util.toBytes(row.fuel) or ''
  return row
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
        b.name == 'computercraft:turtle_expanded' or
        b.name == 'computercraft:turtle' then
          table.insert(candidates, b)
      end

      if b.name == 'minecraft:chest' or b.name:find('shulker') then
        chestPoint = b
      end

      -- add relevant blocks to queue
      b.x = gpt.x + b.x
      b.y = gpt.y + b.y
      b.z = gpt.z + b.z
      b.pkey = table.concat({ b.x, b.y, b.z }, ':')
      if blockTypes[b.key] and inBox(b) then
        if not Util.any(turtles, function(t)
            return t.pt and t.pt.pkey == b.pkey
          end) then
          queue[b.pkey] = b
        end
      else
        queue[b.pkey] = nil
      end
      return acc
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
	row.count = Util.toBytes(row.count) .. ' '
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

  elseif event.type == 'pause' then
    paused = true
    Util.merge(event.button, pauseResume[2])
    event.button:draw()

  elseif event.type == 'resume' then
    paused = false
    Util.merge(event.button, pauseResume[1])
    event.button:draw()

  elseif event.type == 'contain' then
    local pt = { gps.locate() }
    local pos = {
      x = pt[1],
      y = pt[2],
      z = pt[3],
    }

    if not box then
      offset = {
        x = math.floor(pos.x),
        y = math.floor(pos.y),
        z = math.floor(pos.z),
      }
      box = {
        x = math.floor(pos.x),
        y = math.floor(pos.y) - 1,
        z = math.floor(pos.z),
      }
      containTab.textArea.value = containerText[2]
    elseif not box.ex then
      box.ex = math.floor(pos.x)
      box.ey = math.floor(pos.y) - 1
      box.ez = math.floor(pos.z)
      box = Point.normalizeBox(box)
      containTab.textArea.value = containerText[3]
    else
      box = nil
      containTab.textArea.value = containerText[1]
    end

    containTab.textArea:draw()
    drawContainer(pos)

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
  if not abort and not paused then
    page:scan()
  end
end)

Event.onInterval(1, function()
  for id,v in pairs(network) do
    if v.fuel then
      if pool[id] then
        pool[id].fuel = v.fuel
        pool[id].distance = v.distance
      end
    end
  end

  if abort and Util.size(turtles) == 0 then
    Event.exitPullEvents()
  end

  if turtlesTab.enabled then
    turtlesTab.grid:update()
    turtlesTab.grid:draw()
  end

  page.info:draw()
  page.info:sync()

  if canvas then
    local text = string.format('Turtles: %s\nQueue: %s',
      Util.size(turtles), Util.size(queue))
    canvas.text.setText(text)
  end
end)

Event.onTimeout(.1, function()
  page:scan()
  blocksTab.grid:setValues(page.totals)
  blocksTab.grid:draw()
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

if canvas then
  canvas3d.clear()
  canvas.group.remove()
end
