local Equipper   = require('turtle.equipper')
local GPS        = require('gps')
local Point      = require('point')
local Util       = require('util')

local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/superTreefarm.lua'

local FUEL_BASE = 0
local FUEL_DIRE = FUEL_BASE + 10
local FUEL_GOOD = FUEL_BASE + 2000

local MIN_CHARCOAL = 24
local MIN_SAPLINGS = 32
local MAX_SAPLINGS = 48

local GRID = {
  TL = { x =  8, y = 0, z = -7 },
  TR = { x =  8, y = 0, z =  8 },
  BL = { x = -7, y = 0, z = -7 },
  BR = { x = -7, y = 0, z =  8 },
}

local HOME_PT = { x = 0, y = 0, z = 0, heading = 0 }

local DIG_BLACKLIST = {
  [ 'minecraft:furnace'     ] = true,
  [ 'minecraft:lit_furnace' ] = true,
  [ 'minecraft:chest'       ] = true,
}

local APPLE          = 'minecraft:apple:0'
local CHARCOAL       = 'minecraft:coal:1'
local CHEST          = 'minecraft:chest:0'
local COBBLESTONE    = 'minecraft:cobblestone:0'
local CRAFTING_TABLE = 'minecraft:crafting_table:0'
local PICKAXE        = 'minecraft:diamond_pickaxe'
local DIRT           = 'minecraft:dirt:0'
local FURNACE        = 'minecraft:furnace:0'
local MODEM          = 'computercraft:peripheral:1'
local LOG            = 'minecraft:log'
local LOG2           = 'minecraft:log2'
local OAK_LOG        = 'minecraft:log:0'
local OAK_PLANK      = 'minecraft:planks:0'
local OAK_SAPLING    = 'minecraft:sapling:0'
local SAPLING        = 'minecraft:sapling'
local SCANNER        = 'plethora:module:2'
local SENSOR         = 'plethora:module:3'
local STICK          = 'minecraft:stick:0'
local STONE          = 'minecraft:stone:0'
local TORCH          = 'minecraft:torch:0'

local ALL_SAPLINGS = { }

local state = Util.readTable('usr/config/superTreefarm') or {
  trees = {
    { x = 1, y = 0, z = 0 }
  }
}

local clock = os.clock()

local function equip(side, item, rawName)
  -- is it already equipped on the correct side?
  local equipped = peripheral.getType(side)
  if equipped == item then
    return true
  end

  -- is it equipped on the opposite side?
  -- will not work for non-peripheral items :(
  local osides = { left = 'right', right = 'left' }
  if peripheral.getType(osides[side]) == item then
    if not turtle.selectSlotWithQuantity(0) then
      error('No slots available')
    end
    turtle.equip(osides[side])

  elseif not turtle.has(rawName or item) then
    -- don't have the item - unequip that side to see if it's the correct item
    if not turtle.selectSlotWithQuantity(0) then
      error('No slots available')
    end
    turtle.equip(side)
  end

  -- TODO: if the non-peripheral item was equipped on the other side, then this will not work

  if not turtle.has(rawName or item) then
    error('Missing ' .. (rawName or item))
  end

  if not turtle.equip(side, rawName or item) then
    error('Unable to equip ' .. (rawName or item))
  end

  turtle.select(1)
end

local function inspect(fn)
  local s, item = fn()
  if s and item then
    return item.name .. ':' .. item.metadata
  end
  return 'minecraft:air:0'
end

local function setState(key, value)
  state[key] = value
  Util.writeTable('usr/config/superTreefarm', state)
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
    if not turtle.has(FURNACE) then
      getCobblestone(8)
    end

    if turtle.has(FURNACE) or craftItem(FURNACE) then
      turtle.drop(COBBLESTONE)
      local furnacePt = { x = GRID.BL.x + 1, y = 1, z = GRID.BL.z + 1 }
      turtle.placeAt(furnacePt, FURNACE)
      setState('furnace', furnacePt)
    end
  end
  turtle.addWorldBlock(state.furnace)
end

local function createChests()
  if state.chest then
    return
  end
  if turtle.getFuelLevel() > FUEL_GOOD and
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
       (turtle.getItemCount(LOG) > 16 or
        turtle.getItemCount(LOG2) > 16) then

      print('Storing logs')
      turtle.pathfind(Point.above(state.chest))
      turtle.dropDown(LOG)
      turtle.dropDown(LOG2)

      for _, sapling in pairs(ALL_SAPLINGS) do
        if sapling.count > MAX_SAPLINGS then
          turtle.dropDown(sapling.key, sapling.count - MAX_SAPLINGS)
        end
      end

      turtle.dropDown(APPLE)
    end
  end

  return true
end

local function eatSaplings()
  Util.each(ALL_SAPLINGS, function(sapling)
    if sapling.count > MAX_SAPLINGS then
      turtle.refuel(sapling.key, sapling.count - MAX_SAPLINGS)
    end
  end)
  return true
end

local function placeTorches()
  if state.torches then
    return
  end

  local slots = turtle.getSummedInventory()
  if turtle.getFuelLevel() > 100 and
     slots[CHARCOAL] and
     slots[CHARCOAL].count >= MIN_CHARCOAL and
     turtle.canCraft(TORCH, 4, slots) then

    print('Placing torches')

    if turtle.has(TORCH, 4) or craftItem(TORCH, 4) then
      local pts = { }
      for x = -4, 4, 8 do
        for z = -4, 4, 8 do
          table.insert(pts, { x = x, y = 0, z = z })
        end
      end
      turtle.addWorldBlocks(pts)
      Point.eachClosest(turtle.point, pts, function(pt)
        turtle.placeDownAt(pt, TORCH)
      end)
      turtle.refuel(STICK)
      turtle.refuel(OAK_PLANK)
      setState('torches', pts)
    end
  end

  return true
end

local function countSaplings()
  local slots = turtle.getSummedInventory()
  ALL_SAPLINGS = { }

  for _, slot in pairs(slots) do
    if slot.name == SAPLING then
      table.insert(ALL_SAPLINGS, slot)
    end
  end
  if #ALL_SAPLINGS == 0 then
    table.insert(ALL_SAPLINGS, { name = OAK_SAPLING, count = 0 })
  end

  return true
end

local function randomSapling()
  local sapling = ALL_SAPLINGS[math.random(1, #ALL_SAPLINGS)]

  if sapling.count > 0 then
    sapling.count = sapling.count - 1
    return sapling.key
  end
end

local function makeKey(b)
  return table.concat({ b.x, b.y, b.z }, ':')
end

local function findDroppedSaplings()
  Equipper.equipLeft(SENSOR, 'plethora:sensor')
  local raw = peripheral.call('left', 'sense')

  local sensed = Util.reduce(raw, function(acc, b)
    Point.rotate(b, state.home.heading)
    b.x = Util.round(b.x) + turtle.point.x
    b.y = math.ceil(b.y) + turtle.point.y
    b.z = Util.round(b.z) + turtle.point.z
    if b.y == 0 and string.find(b.displayName, 'sapling', 1, true) then
      b.sapling = true
      acc[makeKey(b)] = b
    end
    return acc
  end, { })

  return sensed
end

local function scan(pt, filter, blocks)
  turtle.pathfind(pt)

  Equipper.equipLeft(SCANNER, 'plethora:scanner')
  local raw = peripheral.call('left', 'scan')

  return Util.reduce(raw, function(acc, b)
    if b.y >= 0 then
      Point.rotate(b, state.home.heading)
      b.x = b.x + turtle.point.x
      b.y = b.y + turtle.point.y
      b.z = b.z + turtle.point.z
      if filter(b) then
        acc[makeKey(b)] = b
      end
    end
    return acc
  end, blocks or { })
end

local function getPlantLocations(blocks)
  countSaplings()

  Util.each(state.trees, function(sapling)
    local key = makeKey(sapling)
    local b = blocks[key]
    if b then
      if b.name == SAPLING then
        blocks[key] = nil
      else
        b.plant = randomSapling()
      end
      return
    end
    b = Util.shallowCopy(sapling)
    b.plant = randomSapling()
    if b.plant then
      blocks[key] = b
    end
  end)
end

local function fellTrees(blocks)
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

  if turtle.point.y == 0 then
    if #state.trees == 1 and turtle.getFuelLevel() == 0 then
      turtle.dig()
    end
    turtle.up()
  end
  for pt in Point.iterateClosest(turtle.point, blocks) do
    if pt.y == 0 then
      if pt.sapling then
        repeat until not turtle.suckDownAt(pt)
      else
        turtle.digDownAt(pt)
        if pt.plant then
          turtle.placeDown(pt.plant)
          turtle.select(1)
        end
      end
    else
      turtle.digAt(pt)
    end
  end

  desperateRefuel(FUEL_BASE + 100)
  turtle.clearMoveCallback()

  return true
end

local function fell()
  local function filter(b)
    return b.y >= 0 and (b.name == LOG or b.name == LOG2 or b.name == SAPLING)
  end

  local fuel = turtle.getFuelLevel()
  local sensed = { }

  -- determine if we need saplings
  if not Util.every(ALL_SAPLINGS, function(sapling)
      return sapling.count >= MIN_SAPLINGS
    end) then
      sensed = findDroppedSaplings()
  end

  -- low scan
  local blocks = scan(HOME_PT, filter)

  local pt = Util.shallowCopy(HOME_PT)
  while Util.any(blocks, function(b) return b.y > pt.y + 6 end) do
    -- tree might be above low scan range, do a scan higher up
    Equipper.equipLeft(PICKAXE)
    pt.y = pt.y + 8
    blocks = scan(pt, filter, blocks)
  end

  Util.merge(blocks, sensed)

  -- add any locations that need saplings
  getPlantLocations(blocks)

  Equipper.equipLeft(PICKAXE)
  if not Util.empty(blocks) then
    print('Chopping')

    fellTrees(blocks)

    print('Used ' .. (fuel - turtle.getFuelLevel()) .. ' fuel')
  end

  return true
end

local function moreTrees()
  if #state.trees > 1 then
    return
  end

  if not state.chest or turtle.getItemCount(OAK_SAPLING) < 2 then
    return true
  end

  print('Adding more trees')

  local singleTree = state.trees[1]

  state.trees = { }
  for x = -2, 2, 1 do
    for z = -2, 2, 1 do
      if x ~= 0 or z ~= 0 then
        local tree = { x = x, y = 0, z = z }
        table.insert(state.trees, tree)
        turtle.addWorldBlock(tree)
      end
    end
  end

  turtle.digAt(singleTree)

  setState('trees', state.trees)

  countSaplings()
  Point.eachClosest(turtle.point, state.trees, function(pt)
    local sapling = randomSapling()
    if sapling then
      turtle.placeDownAt(pt, sapling)
    end
  end)
end

local function findHome()
  local pt = GPS.getPoint(2) or error('GPS not found')

  Equipper.equipLeft(SCANNER, 'plethora:scanner')

  local facing = peripheral.call('left', 'getBlockMeta', 0, 0, 0).state.facing
  pt.heading = Point.facings[facing].heading

  Equipper.equipLeft(PICKAXE)

  if not state.home then
    setState('home', pt)
  end

  -- convert to relative coordinates
  turtle.setPoint({
    x = pt.x - state.home.x,
    y = pt.y - state.home.y,
    z = pt.z - state.home.z,
    heading = pt.heading,
  })

  Point.rotate(turtle.point, state.home.heading)
  turtle.setHeading(state.home.heading)
  turtle.point.heading = 0

  turtle.setPathingBox({
    x  = GRID.TL.x,
    y  = GRID.TL.y,
    z  = GRID.TL.z,
    ex = GRID.BR.x,
    ey = 32,
    ez = GRID.BR.z,
  })

  turtle.setPersistent(true)
  turtle.addWorldBlocks(state.trees)
  if state.torches and type(state.torches) == 'table' then
    turtle.addWorldBlocks(state.trees)
  end
end

local function returnHome()
  turtle.pathfind(HOME_PT)
  return true
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
  Equipper.equipRight(MODEM, 'modem')
  Equipper.equipLeft(PICKAXE)

  local slots = turtle.getSummedInventory()

  if not slots[CHEST] or not slots[CRAFTING_TABLE] or not slots[SCANNER] or not slots[SENSOR] then
    error([[
Required:
  * chest
  * crafting table
  * block scanner
  * entity sensor]])
  end

  if not fs.exists(STARTUP_FILE) then
    Util.writeFile(STARTUP_FILE,
      [[os.sleep(1)
shell.openForegroundTab('superTreefarm.lua')]])
    print('Autorun program created: ' .. STARTUP_FILE)
  end
end

local tasks = {
  { desc = 'Startup check',      fn = startupCheck       },
  { desc = 'Finding home',       fn = findHome           },
  { desc = 'Creating furnace',   fn = createFurnace      },
  { desc = 'Creating chest',     fn = createChests       },
  { desc = 'Counting saplings',  fn = countSaplings      },
  { desc = 'Adding trees',       fn = moreTrees          },
  { desc = 'Emptying furnace',   fn = emptyFurnace       },
  { desc = 'Chopping',           fn = fell               },
  { desc = 'Snacking',           fn = eatSaplings        },
  { desc = 'Making charcoal',    fn = makeSingleCharcoal },
  { desc = 'Making charcoal',    fn = makeCharcoal       },
  --{ desc = 'Placing torches',    fn = placeTorches       },
  { desc = 'Refueling',          fn = refuel             },
  { desc = 'Dropping off items', fn = dropOffItems       },
  { desc = 'Condensing',         fn = turtle.condense    },
  { desc = 'Returning home',     fn = returnHome         },
  { desc = 'Sleeping',           fn = updateClock        },
}

local s, m = turtle.run(function()
  turtle.reset()
  require('farms.crafting')
  --turtle.addFeatures('core.crafting')
  turtle.set({
    attackPolicy = 'attack',
    digPolicy = 'dig',
  })

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
