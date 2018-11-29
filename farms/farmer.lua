_G.requireInjector(_ENV)

local Point       = require('point')
local Util        = require('util')

local device      = _G.device
local fs          = _G.fs
local os          = _G.os
local peripheral  = _G.peripheral
local turtle      = _G.turtle

local CONFIG_FILE = 'usr/config/farmer'
local STARTUP_FILE = 'usr/autorun/farmer.lua'

local scanner = device['plethora:scanner'] or
  turtle.equip('right', 'plethora:module:2') and device['plethora:scanner'] or
  error('Plethora scanner required')

local crops = Util.readTable(CONFIG_FILE) or {
  ['minecraft:wheat'] =
    { seed = 'minecraft:wheat_seeds', mature = 7, action = 'plant' },
  ['minecraft:carrots'] =
    { seed = 'minecraft:carrot', mature = 7, action = 'plant' },
  ['minecraft:potatoes'] =
    { seed = 'minecraft:potato', mature = 7, action = 'plant' },
  ['minecraft:beetroots'] =
    { seed = 'minecraft:beetroot_seeds', mature = 3, action = 'plant' },
  ['minecraft:cocoa'] =
    { seed = 'minecraft:dye:3', mature = 8, action = 'pick' },
  ['minecraft:reeds'] = { action = 'bash' },
  ['minecraft:chorus_flower'] = { action = 'bash' },
  ['minecraft:chorus_plant'] =
    { seed = 'minecraft:chorus_flower', mature = 0, action = 'bash-smash', },
  ['minecraft:melon_block'] = { action = 'smash' },
  ['minecraft:pumpkin'] = { action = 'smash' },
  ['minecraft:chest'] = { action = 'drop' },
  ['minecraft:cactus'] = { action = 'smash' },
}

if not fs.exists(CONFIG_FILE) then
  Util.writeTable(CONFIG_FILE, crops)
end

if not fs.exists(STARTUP_FILE) then
  Util.writeFile(STARTUP_FILE,
    [[os.sleep(1)
shell.openForegroundTab('packages/farms/farmer.lua')]])
end

local retain = Util.transpose {
  "minecraft:diamond_pickaxe",
  "plethora:module:2",
  "plethora:module:3",
}

for _, v in pairs(crops) do
  if v.seed then
    retain[v.seed] = true
  end
end

local function scan()
  local blocks = scanner.scan()
  local summed = turtle.getSummedInventory()
  local doDropOff

  for _,v in pairs(summed) do
    if v.count > 48 then
      doDropOff = true
      break
    end
  end

  Util.filterInplace(blocks, function(b)
    b.action = crops[b.name] and crops[b.name].action

    if b.action == 'bash' then
      return b.y == 0
    end
    if b.action == 'drop' then
      return doDropOff and b.y == -1
    end
    if b.action == 'bash-smash' then
      if b.y == -1 then
        b.action = 'smash'
      end
      if b.y == 0 then
        b.action = 'bash'
      end
      return b.action ~= 'bash-smash'
    end

    if b.action == 'smash' then
      return b.y == -1
    end
    if b.action == 'pick' then
      return b.y == 0 and b.state.age == 2
    end
    if b.action == 'bump' then
      return b.y == 0
    end
    return b.action == 'plant' and
      b.metadata == crops[b.name].mature and
      b.y == -1
  end)

  local harvestCount = 0
  for _,b in pairs(blocks) do
    b.x = b.x + turtle.point.x
    b.y = b.y + turtle.point.y
    b.z = b.z + turtle.point.z
    if b.action ~= 'drop' then
      harvestCount = harvestCount + 1
    end
  end

  return blocks, harvestCount
end

local function harvest(blocks)
  turtle.equip('right', 'minecraft:diamond_pickaxe')

  local dropped

  Point.eachClosest(turtle.point, blocks, function(b)
    turtle.select(1)

    if b.action == 'bash' then
      turtle.digForwardAt(b)

    elseif b.action == 'drop' and not dropped then
      if turtle._goto(Point.above(b)) then
        turtle.eachFilledSlot(function(slot)
          if not retain[slot.name] and not retain[slot.key] then
            turtle.select(slot.index)
            turtle.dropDown()
          end
        end)
        local summed = turtle.getSummedInventory()
        for k,v in pairs(summed) do
          if v.count > 16 then
            turtle.dropDown(k, v.count - 16)
          end
        end

        dropped = true
        turtle.condense()
        turtle.select(1)
      end

    elseif b.action == 'smash' then
      if turtle.digDownAt(b) then
        if crops[b.name].seed then
          turtle.placeDown(crops[b.name].seed)
          turtle.select(1)
        end
      end

    elseif b.action == 'plant' then
      if turtle.digDownAt(b) then
        turtle.placeDown(crops[b.name].seed)
        turtle.select(1)
      end

    elseif b.action == 'bump' then
      if turtle.faceAgainst(b) then
        turtle.equip('right', 'plethora:module:3')
        os.sleep(.5)
        -- search the ground for the dropped cactus
        local sensed = peripheral.call('right', 'sense')
        turtle.equip('right', 'minecraft:diamond_pickaxe')
        Util.filterInplace(sensed, function(s)
          if s.displayName == 'item.tile.cactus' then
            s.x = Util.round(s.x) + turtle.point.x
            s.z = Util.round(s.z) + turtle.point.z
            s.y = -1
            if  Point.distance(b, s) < 6 then
              return true
            end
          end
        end)
        Point.eachClosest(turtle.point, sensed, function(s)
          turtle.suckDownAt(s)
        end)
        turtle.select(1)
      end

    elseif b.action == 'pick' then
      local h = Point.facings[b.state.facing].heading
      local hi = Point.headings[(h + 2) % 4] -- opposite heading

      -- without pathfinding, will be unable to circle log
      if turtle._goto({ x = b.x + hi.xd, z = b.z + hi.zd, heading = h }) then
        if turtle.dig() then
          turtle.place(crops[b.name].seed)
        end
      end
    end
  end)
  turtle.equip('right', 'plethora:module:2')
end

local s, m = turtle.run(function()
  local facing = scanner.getBlockMeta(0, 0, 0).state.facing
  turtle.point.heading = Point.facings[facing].heading

  print('Fuel: ' .. turtle.getFuelLevel())

  --turtle.setPolicy('digOnly')
  turtle.setMovementStrategy('goto')
  repeat
    local blocks, harvestCount = scan()
    if harvestCount > 0 then
      turtle.setStatus('Harvesting')
      harvest(blocks)
      turtle.setStatus('Sleeping')
    end
    os.sleep(10)
    if turtle.getFuelLevel() < 10 then
      error('Out of fuel')
    end
  until turtle.isAborted()
end)

if not s and m then
  error(m)
end
