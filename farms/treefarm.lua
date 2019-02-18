_G.requireInjector(_ENV)

--[[
  Requirements:
    Place turtle against an oak tree or oak sapling
    Area around turtle must be flat and can only be dirt or grass
      (10 blocks in each direction from turtle)
    Turtle must have: crafting table, chest
    Turtle must have a pick equipped on the LEFT side

  Optional:
    Add additional sapling types that can grow with a single sapling

  Notes:
    If the turtle does not get any saplings from the initial tree, place
    down another sapling in front of the turtle.

    The program will be able to survive server restarts as long as it has
    created the cobblestone line. If the program is stopped before that time,
    place the turtle in the original position before restarting the program.
]]--

local Point  = require('point')
local Util   = require('util')

local fs     = _G.fs
local os     = _G.os
local read   = _G.read
local turtle = _G.turtle

local STARTUP_FILE = 'usr/autorun/treefarm.lua'

local FUEL_BASE = 0
local FUEL_DIRE = FUEL_BASE + 10
local FUEL_GOOD = FUEL_BASE + 2000

local MIN_CHARCOAL = 24
local MAX_SAPLINGS = 32

local GRID_WIDTH = 8
local GRID_LENGTH = 10
local GRID = {
  TL = { x =  8, y = 0, z = -8 },
  TR = { x =  8, y = 0, z =  8 },
  BL = { x = -10, y = 0, z = -8 },
  BR = { x = -10, y = 0, z =  8 },
}

local HOME_PT = { x = 0, y = 0, z = 0, heading = 0 }

local DIG_BLACKLIST = {
  [ 'minecraft:furnace'     ] = true,
  [ 'minecraft:lit_furnace' ] = true,
  [ 'minecraft:chest'       ] = true,
}

local COBBLESTONE    = 'minecraft:cobblestone:0'
local CHARCOAL       = 'minecraft:coal:1'
local OAK_LOG        = 'minecraft:log:0'
local OAK_PLANK      = 'minecraft:planks:0'
local CHEST          = 'minecraft:chest:0'
local FURNACE        = 'minecraft:furnace:0'
local SAPLING        = 'minecraft:sapling:0'
local STONE          = 'minecraft:stone:0'
local TORCH          = 'minecraft:torch:0'
local DIRT           = 'minecraft:dirt:0'
local APPLE          = 'minecraft:apple:0'
local STICK          = 'minecraft:stick:0'
local CRAFTING_TABLE = 'minecraft:crafting_table:0'

local ALL_SAPLINGS = {
  SAPLING
}

local state = Util.readTable('usr/config/treefarm') or {
  trees = {
    { x = 1, y = 0, z = 0 }
  }
}

if not fs.exists(STARTUP_FILE) then
  Util.writeFile(STARTUP_FILE,
    [[os.sleep(1)
shell.openForegroundTab('treefarm.lua')]])
  print('Autorun program created: ' .. STARTUP_FILE)
end

local clock = os.clock()

local function inspect(fn)
  local s, item = fn()
  if s and item then
    return item.name .. ':' .. item.metadata
  end
  return 'minecraft:air:0'
end

local function setState(key, value)
  state[key] = value
  Util.writeTable('usr/config/treefarm', state)
end

local function refuel()
  if turtle.getFuelLevel() < FUEL_GOOD then
    local charcoal = turtle.getItemCount(CHARCOAL)
    if charcoal > 1 then
      turtle.refuel(CHARCOAL, math.min(charcoal - 1, MIN_CHARCOAL / 2))
      print('fuel: ' .. turtle.getFuelLevel())
    end
  end
  return true
end

local function safePlaceBlock(item)

  if turtle.placeUp(item) then
    return true
  end

  local s, m = turtle.inspectUp()
  if s and not DIG_BLACKLIST[m.name] then
    turtle.digUp()
    return turtle.placeUp(item)
  end

  turtle.forward()
  return turtle.placeUp(item)
end

local function craftItem(item, qty)
  local success, msg

  if safePlaceBlock(CHEST) then

    os.sleep(.2) -- needed for minecraft 1.12
    Util.print('Crafting %d %s', (qty or 1), item)
    success, msg = turtle.craftItem(item, qty or 1, {
        side = 'top',
        direction = 'down',
      })
    repeat until not turtle.suckUp()

    if not success then
      print(msg)
    end

    turtle.digUp()
  end

  return success
end

local function emptyFurnace()
  if state.cooking then

    print('Emptying furnace')

    turtle.suckDownAt(state.furnace)
    turtle.suckForwardAt(state.furnace)
    turtle.suckUpAt(state.furnace)
    setState('cooking')
  end
end

local function cook(item, count, result, fuel, fuelCount)

  emptyFurnace()

  setState('cooking', true)

  fuel = fuel or CHARCOAL
  fuelCount = fuelCount or math.ceil(count / 8)
  Util.print('Making %d %s', count, result)

  turtle.dropForwardAt(state.furnace, fuel, fuelCount)
  turtle.dropDownAt(state.furnace, item, count)

  count = count + turtle.getItemCount(result)
  turtle.select(1)
  turtle.pathfind(Point.below(state.furnace))

  local lastSuck = os.clock()
  repeat
    os.sleep(1)
    if turtle.suckUp() then
      lastSuck = os.clock()
    end

    if os.clock() - lastSuck > 10 then
      -- sponge bug
      Util.print('Timed out waiting for furnace')
      return
    end
  until turtle.getItemCount(result) >= count

  setState('cooking')
end

local function makeSingleCharcoal()

  local slots = turtle.getSummedInventory()

  if not state.furnace or
     slots[CHARCOAL] or
     not slots[OAK_LOG] or
     slots[OAK_LOG].count < 2 then
    return true
  end

  turtle.faceAgainst(state.furnace)
  if craftItem(OAK_PLANK) then
    cook(OAK_LOG, 1, CHARCOAL, OAK_PLANK, 1)
    turtle.refuel(OAK_PLANK)
  end

  return true
end

local function makeCharcoal()

  local slots = turtle.getSummedInventory()

  if not state.furnace or
     not slots[CHARCOAL] or
     slots[CHARCOAL].count >= MIN_CHARCOAL then
    return true
  end

  local function getLogSlot()
    local maxslot = { count = 0 }
    for k,slot in pairs(slots) do
      if string.match(k, 'minecraft:log') then
        if slot.count > maxslot.count then
          maxslot = slot
        end
      end
    end
    return maxslot
  end

  repeat
    slots = turtle.getSummedInventory()

    local charcoal = slots[CHARCOAL].count
    local slot     = getLogSlot(slots)

    if slot.count < 8 then
      break
    end

    local toCook = math.min(charcoal, math.floor(slot.count / 8))
    toCook = math.min(toCook, math.floor((MIN_CHARCOAL + 8 - charcoal) / 8))
    toCook = toCook * 8

    cook(slot.key, toCook, CHARCOAL)

  until charcoal + toCook >= MIN_CHARCOAL

  return true
end

local function getCobblestone(count)

  local slots = turtle.getSummedInventory()

  if not slots[COBBLESTONE] or slots[COBBLESTONE].count < count then

    print('Collecting cobblestone')

    slots[COBBLESTONE] = true
    slots[DIRT] = true

    local pt = Point.copy(GRID.BR)
    pt.x = GRID.BR.x + 2
    pt.z = GRID.BR.z - 2

    turtle.pathfind(pt)

    repeat
      turtle.select(1)
      turtle.digDown()
      turtle.down()
      for _ = 1, 4 do
        if inspect(turtle.inspect) == STONE then
          turtle.dig()
        end
        turtle.turnRight()
      end

      for item in pairs(turtle.getSummedInventory()) do
        if not slots[item] then
          turtle.drop(item)
        end
      end

    until turtle.getItemCount(COBBLESTONE) >= count

    turtle.go(pt)
    turtle.placeDown(DIRT)

    turtle.drop(DIRT)
  end
end

local function createFurnace()

  if not state.furnace then
    if turtle.getFuelLevel() < FUEL_BASE + 100 then
      return true -- try again later
    end
    print('Adding a furnace')
    getCobblestone(8)

    if turtle.has(FURNACE) or craftItem(FURNACE) then
      -- turtle.drop(COBBLESTONE)
      local furnacePt = { x = GRID.BL.x + 2, y = 1, z = GRID.BL.z + 2 }
      turtle.placeAt(furnacePt, FURNACE)
      setState('furnace', furnacePt)
    end
  end
end

local function createPerimeter()

  if not state.perimeter then
    if not state.furnace or
       turtle.getFuelLevel() < FUEL_BASE + 500 or
       turtle.getItemCount(OAK_LOG) == 0 or
       not craftItem(OAK_PLANK, 2) then
      return true
    end

    print('Creating a perimeter')

    getCobblestone(GRID_WIDTH * 2 + 1)
    if not turtle.has(STONE, 2) then
      cook(COBBLESTONE, 2, STONE, OAK_PLANK, 2)
    end
    turtle.refuel(OAK_PLANK)

    turtle.pathfind(GRID.BL)
    turtle.digDown()
    turtle.placeDown(STONE)

    turtle.setMoveCallback(function()
      local target = COBBLESTONE
      if math.abs(turtle.point.x) == GRID_LENGTH and
         math.abs(turtle.point.z) == GRID_WIDTH then
         target = STONE
       end

      if inspect(turtle.inspectDown) ~= target then
        turtle.digDown()
        turtle.placeDown(target)
      end
    end)

    turtle.pathfind(GRID.BR)

    turtle.clearMoveCallback()
    turtle.drop(COBBLESTONE)
    turtle.drop(DIRT)

    setState('perimeter', true)
  end
end

local function createChests()
  if state.chest then
    return
  end
  if state.perimeter and
     turtle.getFuelLevel() > FUEL_GOOD and
     turtle.canCraft(CHEST, 4, turtle.getSummedInventory()) then

    print('Adding storage')
    if turtle.has(CHEST, 2) or craftItem(CHEST, 2) then

      local pt = Point.copy(GRID.BL)
      pt.x = pt.x + 1
      pt.y = pt.y - 1

      pt.z = pt.z + 1

      turtle.digDownAt(pt)
      turtle.placeDown(CHEST)

      pt.z = pt.z + 1

      turtle.digDownAt(pt)
      turtle.placeDown(CHEST)

      setState('chest', Util.shallowCopy(pt))

      turtle.drop(DIRT)
      turtle.refuel(OAK_PLANK)
    end
  end
  return true
end

local function dropOffItems()

  if state.chest then
    local slots = turtle.getSummedInventory()

    if state.chest and
       slots[CHARCOAL] and
       slots[CHARCOAL].count >= MIN_CHARCOAL and
       (turtle.getItemCount('minecraft:log') > 0 or
        turtle.getItemCount('minecraft:log2') > 0) then

      print('Storing logs')
      turtle.pathfind(Point.above(state.chest))
      turtle.dropDown('minecraft:log')
      turtle.dropDown('minecraft:log2')

      for _, sapling in pairs(ALL_SAPLINGS) do
        if slots[sapling] and slots[sapling].count > MAX_SAPLINGS then
          turtle.dropDown(sapling, slots[sapling].count - MAX_SAPLINGS)
        end
      end

      turtle.dropDown(APPLE)
    end
  end

  return true
end

local function eatSaplings()

  local slots = turtle.getSummedInventory()

  for _, sapling in pairs(ALL_SAPLINGS) do
    if slots[sapling] and slots[sapling].count > MAX_SAPLINGS then
      turtle.refuel(sapling, slots[sapling].count - MAX_SAPLINGS)
    end
  end
  return true
end

local function placeTorches()
  if state.torches then
    return
  end

  if turtle.getFuelLevel() > 100 and
     turtle.canCraft(TORCH, 4, turtle.getSummedInventory()) then

    print('Placing torches')

    if turtle.has(TORCH, 4) or craftItem(TORCH, 4) then
      local pts = { }
      for x = -4, 4, 8 do
        for z = -4, 4, 8 do
          table.insert(pts, { x = x, y = 0, z = z })
        end
      end
      Point.eachClosest(turtle.point, pts, function(pt)
        turtle.placeAt(pt, TORCH)
      end)
      turtle.refuel(STICK)
      turtle.refuel(OAK_PLANK)
      setState('torches', true)
    end
  end

  return true
end

local function randomSapling()

  local sapling = SAPLING

  if #state.trees > 1 then
    ALL_SAPLINGS = { }

    local slots = turtle.getFilledSlots()
    for _, slot in pairs(slots) do
      if slot.name == 'minecraft:sapling' then
        table.insert(ALL_SAPLINGS, slot.key)
      end
    end
    if #ALL_SAPLINGS > 0 then
      sapling = ALL_SAPLINGS[math.random(1, #ALL_SAPLINGS)]
    end
  end

  return sapling
end

local function fellTree(pt)

  local function desperateRefuel(min)
    if turtle.getFuelLevel() < min then
      local logs = turtle.getItemCount(OAK_LOG)
      if logs > 0 then
        if craftItem(OAK_PLANK, math.min(8, logs * 4)) then
          turtle.refuel(OAK_PLANK)
          print('fuel: ' .. turtle.getFuelLevel())
        end
      end
    end
  end

  turtle.setMoveCallback(function() desperateRefuel(FUEL_DIRE) end)

  desperateRefuel(FUEL_DIRE)

  if turtle.digUpAt(Point.above(pt)) then
    turtle.level(
      { x = GRID_WIDTH-1,    y = 1,  z = GRID_WIDTH-1    },
      { x = -(GRID_WIDTH-1), y = 50, z = -(GRID_WIDTH-1) },
      Point.above(pt))
  end

  desperateRefuel(FUEL_BASE + 100)
  turtle.clearMoveCallback()
  turtle.set({ attackPolicy = "attack" })

  return true
end

local function fell()

  local pts = Util.shallowCopy(state.trees)

  local rpt = table.remove(pts, math.random(1, #pts))

  -- give the pathfinder hints about what to avoid (state.trees)
  if not turtle.faceAgainst(rpt, { blocks = Util.shallowCopy(state.trees) }) or
     not string.match(inspect(turtle.inspect), 'minecraft:log') then
    return true
  end

  print('Chopping')

  local fuel = turtle.getFuelLevel()

  -- push this point to the start of this list
  table.insert(pts, 1, rpt)

  Point.eachClosest(turtle.point, pts, function(pt)
    if turtle.faceAgainst(pt, { blocks = Util.shallowCopy(state.trees) }) and
       string.match(inspect(turtle.inspect), 'minecraft:log') then
      turtle.dig()
      fellTree(pt)
    end
    turtle.placeAt(pt, randomSapling())
    turtle.select(1)
  end)

  print('Used ' .. (fuel - turtle.getFuelLevel()) .. ' fuel')
  return true
end

local function moreTrees()

  if #state.trees > 1 then
    return
  end

  if not state.chest or turtle.getItemCount('minecraft:sapling') < 15 then
    return true
  end

  print('Adding more trees')

  local singleTree = state.trees[1]

  state.trees = { }
  for x = -2, 2, 1 do
    for z = -2, 2, 2 do
      table.insert(state.trees, { x = x, y = 0, z = z })
    end
  end

  turtle.digAt(singleTree)
  fellTree(singleTree)

  setState('trees', state.trees)

  Point.eachClosest(turtle.point, state.trees, function(pt)
    turtle.placeDownAt(pt, randomSapling())
  end)
end

local function getTurtleFacing(block)
  local directions = {
    [5] = 2,
    [3] = 3,
    [4] = 0,
    [2] = 1,
  }

  if not safePlaceBlock(block) then
    error('unable to place chest above')
  end
  local _, bi = turtle.inspectUp()
  turtle.digUp()
  return directions[bi.metadata]
end

local function saveTurtleFacing()
  if not state.facing then
    setState('facing', getTurtleFacing(CHEST))
  end
end

local function findGround()
  print('Locating ground level')
  turtle.setPoint(HOME_PT)

  while true do
    local s, block = turtle.inspectDown()

    if not s then block = { name = 'minecraft:air', metadata = 0 } end
    local b = block.name .. ':' .. block.metadata

    if b == 'minecraft:dirt:0' or
       b == 'minecraft:grass:0' or
       block.name == 'minecraft:chest' then
      break
    end

    if b == COBBLESTONE then
      turtle.back()
      local s2, b2 = turtle.inspectDown()
      if not s2 then
        error('lost')
      end
      if b2.name == COBBLESTONE then
        turtle.turnLeft()
        turtle.back()
      end
      break
    end

    if b == STONE then
      error('lost')
    end

    if b == TORCH or DIG_BLACKLIST[block.name] then
      turtle.forward()
    else
      turtle.digDown()
      turtle.down()
    end

    if turtle.point.y < -20 then
      error('lost')
    end
  end
  turtle.setPoint(HOME_PT)
end

local function findHome()

  if not state.perimeter then
    return
  end

  print('Determining location')
  turtle.point.heading = (getTurtleFacing(CHEST) - state.facing) % 4

  local pt = Point.copy(turtle.point)

  while inspect(turtle.inspectDown) ~= COBBLESTONE do
    pt.x = pt.x - 1
    turtle.pathfind(pt)
    if pt.x < -20 then
      error('lost')
    end
  end
  while inspect(turtle.inspectDown) == COBBLESTONE do
    pt.z = pt.z - 1
    turtle.pathfind(pt)
    if pt.z < -20 then
      error('lost')
    end
  end

  turtle.setPoint({
    x = -(GRID_LENGTH),
    y = 0,
    z = -GRID_WIDTH,
    heading = turtle.point.heading
  })

  -- when pathfinding - don't leave this box
  turtle.setPathingBox({
    x  = GRID.TL.x,
    y  = GRID.TL.y,
    z  = GRID.TL.z,
    ex = GRID.BR.x,
    ey = 5,
    ez = GRID.BR.z,
  })
end

local function updateClock()

  local ONE_HOUR = 50

  if os.clock() - clock > ONE_HOUR then
    clock = os.clock()
  else
    print('sleeping for ' .. math.floor(ONE_HOUR - (os.clock() - clock)))
    os.sleep(ONE_HOUR - (os.clock() - clock))
    clock = os.clock()
  end

  return true
end

local function startupCheck()
  local slots = turtle.getSummedInventory()

  if not slots[CHEST] or not slots[CRAFTING_TABLE] then
    error('A chest and crafting table must be in inventory')
  end

  if state.facing and not state.perimeter then
    print('Perimeter has not been established.')
    print('Enter to continue if turtle is in the original starting position.')
    read()
  end
end

local tasks = {
  { desc = 'Startup check',      fn = startupCheck       },
  { desc = 'Finding ground',     fn = findGround         },
  { desc = 'Determine facing',   fn = saveTurtleFacing   },
  { desc = 'Finding home',       fn = findHome           },
  { desc = 'Emptying furnace',   fn = emptyFurnace       },
  { desc = 'Adding trees',       fn = moreTrees          },
  { desc = 'Chopping',           fn = fell               },
--  { desc = 'Snacking',           fn = eatSaplings        },
  { desc = 'Creating chest',     fn = createChests       },
  { desc = 'Creating furnace',   fn = createFurnace      },
  { desc = 'Making charcoal',    fn = makeSingleCharcoal },
  { desc = 'Making charcoal',    fn = makeCharcoal       },
  { desc = 'Creating perimeter', fn = createPerimeter    },
  { desc = 'Placing torches',    fn = placeTorches       },
  { desc = 'Refueling',          fn = refuel             },
  { desc = 'Dropping off items', fn = dropOffItems       },
  { desc = 'Condensing',         fn = turtle.condense    },
  { desc = 'Sleeping',           fn = updateClock        },
}

local s, m = turtle.run(function()

  require('core.turtle.crafting')
  require('core.turtle.level')
  --turtle.addFeatures('level', 'core.crafting')
  turtle.set({ attackPolicy = "attack" })

  while not turtle.isAborted() do
    print('fuel: ' .. turtle.getFuelLevel())
    for _,task in ipairs(Util.shallowCopy(tasks)) do
      --print(task.desc)
      turtle.setStatus(task.desc)
      turtle.select(1)
      if not task.fn() then
        Util.filterInplace(tasks, function(v) return v.fn ~= task.fn end)
      end
    end
  end
end)

if not s then
  error(m or 'Failed')
end
