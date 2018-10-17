--[[
  Efficient miner

  GPS is required.

  Miner Requires:
    Diamond pick
    Ender Modem
    Plethora scanner
    Bucket
--]]
_G.requireInjector(_ENV)

local Event   = require('event')
local GPS     = require('gps')
local Point   = require('point')
local UI      = require('ui')
local Util    = require('util')

local colors     = _G.colors
local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral
local read       = _G.read
local turtle     = _G.turtle

UI:configure('scanningMiner', ...)

local args = { ... }
local options = {
  chunks      = { arg = 'c', type = 'number', value = -1,
                 desc = 'Number of chunks to mine' },
  setTrash    = { arg = 's', type = 'flag',   value = false,
                 desc = 'Set trash items' },
  help        = { arg = 'h', type = 'flag',   value = false,
                 desc = 'Displays the options' },
}

local MIN_FUEL = 7500
local LOW_FUEL = 1500
local MAX_FUEL = turtle.getFuelLimit()

local DICTIONARY_FILE = 'usr/config/mining.dictionary'
local PROGRESS_FILE   = 'usr/config/scanning_mining.progress'

local mining
local ignores = {
  ignore = true,
  retain = true,
}

local dictionary = {
  data = Util.readTable(DICTIONARY_FILE) or {
    [ 'minecraft:chest'              ] = 'suck',
    [ 'minecraft:lava'               ] = 'liquid_fuel',
    [ 'minecraft:flowing_lava'       ] = 'liquid_fuel',
    [ 'minecraft:bedrock'            ] = 'ignore',
    [ 'minecraft:flowing_water'      ] = 'ignore',
    [ 'minecraft:water'              ] = 'ignore',
    [ 'minecraft:air'                ] = 'ignore',
    [ 'minecraft:bucket'             ] = 'retain',
    [ 'computercraft:advanced_modem' ] = 'retain',
    [ 'minecraft:diamond_pickaxe'    ] = 'retain',
    [ 'plethora:module'              ] = 'retain',
  },
}

function dictionary:write()
  Util.writeTable(DICTIONARY_FILE, self.data)
end
function dictionary:mineable(name, damage)
  self.data[name .. ':' .. damage] = nil
end
function dictionary:ignore(name, damage)
  if damage then
    self.data[name .. ':' .. damage] = 'ignore'
  else
    self.data[name] = 'ignore'
  end
end
function dictionary:get(name, damage)
  return self.data[name] or self.data[name .. ':' .. damage]
end
function dictionary:isTrash(name, damage)
  return self:get(name, damage) == 'ignore'
end

local page = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      --{ text = 'Mine',   event = 'mine' },
      { text = 'Ignore', event = 'ignore' },
      { text = 'Ignore All', event = 'ignore_all' },
    },
  },
  grid = UI.Grid {
    y = 2, ey = -2,
    sortColumn = 'name',
    columns = {
      { heading = 'Count',    key = 'count', width = 5 },
      { heading = 'Resource', key = 'displayName' },
    },
  },
  statusBar = UI.StatusBar {
    columns = {
      { key = 'status' },
      { key = 'fuel', width = 6 },
    },
  },
  accelerators = {
    q = 'cancel',
  }
}

function page:eventHandler(event)
  local t = self.grid:getSelected()
  if t then
    if event.type == 'mine' then
      dictionary:mineable(t.name, t.damage)
      dictionary:write()

    elseif event.type == 'ignore' then
      dictionary:ignore(t.name, t.damage)
      dictionary:write()
      self.grid:draw()

    elseif event.type == 'ignore_all' then
      dictionary:ignore(t.name)
      dictionary:write()
      self.grid:draw()
    end
  end
  if event.type == 'quit' then
    turtle.abort(true)
  end
  UI.Page.eventHandler(self, event)
end

function page.grid:getRowTextColor(row, selected)
  if dictionary:get(row.name, row.damage) == 'ignore' then
    return colors.lightGray
  end
  if row.displayName == self.nextBlock then
    return colors.yellow
  end
  return UI.Grid.getRowTextColor(self, row, selected)
end

local function getChunkCoordinates(diameter, index, x, z)
  local dirs = { -- circumference of grid
    { xd =  0, zd =  1, heading = 1 }, -- south
    { xd = -1, zd =  0, heading = 2 },
    { xd =  0, zd = -1, heading = 3 },
    { xd =  1, zd =  0, heading = 0 }  -- east
  }
  -- always move east when entering the next diameter
  if index == 0 then
    dirs[4].x = x + 16
    dirs[4].z = z
    return dirs[4]
  end
  local dir = dirs[math.floor(index / (diameter - 1)) + 1]
  dir.x = x + dir.xd * 16
  dir.z = z + dir.zd * 16
  return dir
end

local function getCornerOf(c)
  return math.floor(c.x / 16) * 16, math.floor(c.z / 16) * 16
end

local function isFinished()
  if mining.chunks ~= -1 then
    local chunks = math.pow(mining.diameter-2, 2) + mining.chunkIndex
    if chunks >= mining.chunks then
      return true
    end
  end
end

local function nextChunk()
  local x, z = getCornerOf({ x = mining.x, z = mining.z })
  local points = math.pow(mining.diameter, 2) - math.pow(mining.diameter-2, 2)
  mining.chunkIndex = mining.chunkIndex + 1

  if mining.chunkIndex >= points then
    mining.diameter = mining.diameter + 2
    mining.chunkIndex = 0
  end

  local nc = getChunkCoordinates(mining.diameter, mining.chunkIndex, x, z)

  -- enter next chunk
  mining.x = nc.x
  mining.z = nc.z

  Util.writeTable(PROGRESS_FILE, mining)

  return not isFinished()
end

local function status(newStatus)
  turtle.setStatus(newStatus)
  page.statusBar:setValue('status', newStatus)
  page.statusBar:draw()
  page:sync()
end

local function refuel()
  if turtle.getFuelLevel() < MIN_FUEL then
    local oldStatus = turtle.getStatus()
    status('refueling')

    turtle.refuel('minecraft:coal:0', 32)
    if turtle.getFuelLevel() < MIN_FUEL then
      turtle.eachFilledSlot(function(slot)
        if turtle.getFuelLevel() < MIN_FUEL then
          turtle.select(slot.index)
          turtle.refuel(64)
        end
      end)
    end
    status(oldStatus)
  end

  turtle.select(1)
end

local function safeGoto(x, z, y, h)
  local oldStatus = turtle.getStatus()

  while not turtle._goto({ x = x, z = z, y = y or turtle.point.y, heading = h }) do
    status('stuck')
    if turtle.isAborted() then
      return false
    end
    os.sleep(3)
  end
  turtle.setStatus(oldStatus)
  return true
end

local function safeGotoY(y)
  local oldStatus = turtle.getStatus()
  while not turtle.gotoY(y) do
    status('stuck')
    if turtle.isAborted() then
      return false
    end
    os.sleep(1)
  end
  turtle.setStatus(oldStatus)
  return true
end

local function unload()
  local oldStatus = turtle.getStatus()
  status('unloading')
  local pt = Util.shallowCopy(turtle.point)
  safeGotoY(0)

  safeGoto(0, 0, 0)
  if not turtle.detectUp() then
    error('no chest')
  end
  local slots = turtle.getFilledSlots()
  for _,slot in pairs(slots) do
    local action = dictionary:get(slot.name, slot.damage)
    if not ignores[action] then
      turtle.select(slot.index)
      turtle.dropUp(64)
    end
  end
  turtle.condense()
  turtle.select(1)
  safeGoto(pt.x, pt.z, 0, pt.heading)

  safeGotoY(pt.y)
  status(oldStatus)
end

local function ejectTrash()
  turtle.eachFilledSlot(function(slot)
    if dictionary:isTrash(slot.name, slot.damage) then
      turtle.select(slot.index)
      turtle.dropDown(64)
    end
  end)
end

local function checkSpace()
  if turtle.getItemCount(15) > 0 then
    refuel()
    local oldStatus = turtle.getStatus()
    status('condensing')
    ejectTrash()
    turtle.condense()
    if turtle.getItemCount(15) > 0 then
      unload()
    end
    status(oldStatus)
    turtle.select(1)
  end
end

local function collectDrops(suckAction)
  for _ = 1, 50 do
    checkSpace()
    if not suckAction() then
      break
    end
  end
end

local function equip(side, item)
  if not turtle.equip(side, item) then
    turtle.selectSlotWithQuantity(0)
    turtle.equip(side)
    if not turtle.equip(side, item) then
      error('Unable to equip ' .. item)
    end
  end
end

local function scan()
  equip('left', 'plethora:module')
  local blocks = peripheral.call('left', 'scan')
  equip('left', 'minecraft:diamond_pickaxe')

  local bedrock = -256
  local counts = { }

  for _, b in pairs(blocks) do
    if b.x == 0 and b.y == 0 and b.z == 0 then
      b.name = 'minecraft:air'
    end
    b.x = b.x + turtle.point.x
    b.y = b.y + turtle.point.y
    b.z = b.z + turtle.point.z

    if b.name == 'minecraft:bedrock' then
      if b.y > bedrock then
        bedrock = b.y
      end
    end
  end

  Util.filterInplace(blocks, function(b)
    if b.y >= 0 or
       (b.action == 'liquid_fuel' and b.y <= bedrock) then
      return false

    elseif b.y >= bedrock then
      b.action = dictionary:get(b.name, b.metadata) or 'mine'

      if ignores[b.action] then
        return false
      end

      local key = b.name .. ':' .. b.metadata
      if not counts[key] then
        counts[key] = {
          displayName = key,
          name = b.name,
          damage = b.metadata,
          count = 1
      }
      else
        counts[key].count = counts[key].count + 1
      end
      return true
    end
  end)

  turtle.select(1)

  local dirty = true

  local function display()
    if dirty then
      page.grid:draw()
      page:sync()
    end
    dirty = false
  end

  page.grid:setValues(counts)
  page.grid:draw()
  display()

  status('mining')

  local i = #blocks
  Point.eachClosest(turtle.point, blocks, function(b)
    if turtle.isAborted() then
      error('aborted')
    end

    page.grid.nextBlock = b.name .. ':' .. b.metadata

    -- Get the action again in case the user has ignored via UI
    b.action = dictionary:get(b.name, b.metadata) or 'mine'
    if b.action == 'suck' or b.action == 'mine' then
      if b.action == 'suck' then
        local pt = turtle.moveAgainst(b)
        collectDrops(turtle.getAction(pt.direction).suck)
      end
      checkSpace()
      local s, m
      if b.y == bedrock then
        s, m = turtle.digDownAt(b)
      else
        s, m = turtle.digAt(b)
      end
      if not s then
        page.statusBar:setValue('status', m)
        page.statusBar:draw()
        page:sync()
        os.sleep(3)
      else
        page.statusBar:setValue('mining', m)
      end
      dirty = true
    elseif b.action == 'liquid_fuel' then
      if turtle.getFuelLevel() < (MAX_FUEL - 1000) then
        if turtle.placeAt(b, 'minecraft:bucket:0') then
          turtle.refuel()
          turtle.select(1)
          dirty = true
        end
      end
    end
    local key = b.name .. ':' .. b.metadata
    counts[key].count = counts[key].count - 1
    i = i - 1
    display()
  end)
end

local function mineChunk()
  local pts = { }

  for i = 1, math.ceil(mining.home.y / 16) do
    pts[i] = { x = mining.x + 8, z = mining.z + 8, y = (i - 1) * 16 + 8 }
    if pts[i].y > mining.home.y - 8 then
      pts[i].y = mining.home.y - 8
    end
    pts[i].y = pts[i].y - mining.home.y -- abs to rel
  end

  Point.eachClosest(turtle.point, pts, function(pt)
    if turtle.isAborted() then
      error('aborted')
    end
    status('scanning ' .. pt.y + mining.home.y - 8 .. '-' .. pt.y + mining.home.y + 8)

    turtle.select(1)
    safeGoto(pt.x, pt.z, pt.y)
    scan()

    if turtle.getFuelLevel() < LOW_FUEL then
      refuel()
      local veryMinFuel = Point.turtleDistance(turtle.point, { x = 0, y = 0, z = 0 }) + 512
      if turtle.getFuelLevel() < veryMinFuel then
        error('Not enough fuel to continue')
      end
    end
  end)
end

local function addTrash()
  local slots = turtle.getFilledSlots()

  for _,slot in pairs(slots) do
    local e = dictionary:get(slot.name, slot.damage)
    if not e or e ~= 'retain' then
      dictionary:ignore(slot.name, slot.damage)
    end
  end

  dictionary:write()
end

-- Startup logic
if not Util.getOptions(options, args) then
  return
end

-- in plethora code, we can override initialize with a scanner version
turtle.initialize = function()
  if turtle.isEquipped('modem') ~= 'right' then
    equip('right', 'computercraft:advanced_modem')
  end

  equip('left', 'minecraft:diamond_pickaxe')

  local function verify(item)
    if not turtle.has(item) then
      error('Missing: ' .. item)
    end
  end

  local items = { 'minecraft:bucket', 'plethora:module' }
  for _,v in pairs(items) do
    verify(v)
  end

  --os.sleep(5)
  local pt = GPS.getPoint(2) or error('GPS not found')
  equip('left', 'plethora:module')
  local facing = peripheral.call('left', 'getBlockMeta', 0, 0, 0).state.facing
  pt.heading = Point.facings[facing].heading
  turtle.setPoint(pt, true)
  equip('left', 'minecraft:diamond_pickaxe')
end

local function main()
  repeat
    mineChunk()
  until not nextChunk()
end

local success, msg

Event.addRoutine(function()
  turtle.reset()

  if not fs.exists(DICTIONARY_FILE) or options.setTrash.value then
    print('Add blocks to ignore, press enter when ready')
    read()
    addTrash()
  end

  ejectTrash()

  turtle.initialize {
    right = 'computercraft:advanced_modem',
    left  = 'minecraft:diamond_pickaxe',
    required = {
      'minecraft:bucket',
      'plethora:module',
    },
    GPS = true,
    minFuel = 100,
    -- searchFor = 'ironchest:iron_shulker_box_white'
  }

  turtle.setMoveCallback(function()
    page.statusBar:setValue('fuel', Util.toBytes(turtle.getFuelLevel()))
    page.statusBar:draw()
    page:sync()
  end)

  mining = Util.readTable(PROGRESS_FILE) or {
    diameter = 1,
    chunkIndex = 0,
    x = 0, z = 0,
    chunks = options.chunks.value,
    home = Point.copy(turtle.point),
    heading = turtle.point.heading, -- always using east for now
  }

  if options.chunks.value ~= -1 then
    mining.chunks = options.chunks.value
  end

  -- use coordinates relative to initial starting point
  turtle.setPoint({
    x = turtle.point.x - mining.home.x,
    y = turtle.point.y - mining.home.y,
    z = turtle.point.z - mining.home.z,
  })

  if not fs.exists(PROGRESS_FILE) then
    Util.writeTable(PROGRESS_FILE, mining)
  end

  turtle.setPolicy(turtle.policies.digAttack)
  turtle.setDigPolicy(turtle.digPolicies.turtleSafe)
  turtle.setMovementStrategy('goto')
  status('mining')

  if isFinished() then
    success = false
    msg = 'Mining complete'
  else
    success, msg = pcall(main)
  end

  status(success and 'finished' or turtle.isAborted() and 'aborting' or 'error')
  if turtle._goto({ x = 0, y = 0, z = 0 }) then
    unload()
  end
  turtle.reset()

  Event.exitPullEvents()
end)

Event.onTerminate(function()
  turtle.abort(true)
end)

UI:setPage(page)
UI:pullEvents()
UI.term:reset()

turtle.reset()

if not success and msg then
  _G.printError(msg)
end
