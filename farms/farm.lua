_G.requireInjector(_ENV)

local Point = require('point')
local Util  = require('util')

local device = _G.device
local fs     = _G.fs
local os     = _G.os
local turtle = _G.turtle

local CONFIG_FILE = 'usr/config/farm'

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
  ['minecraft:reeds'] = { action = 'bash' },
  ['minecraft:melon_block'] = { action = 'smash' },
  ['minecraft:pumpkin'] = { action = 'smash' },
  ['minecraft:chest'] = { action = 'drop' },
}

if not fs.exists(CONFIG_FILE) then
  Util.writeTable(CONFIG_FILE, crops)
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

  Util.filterInplace(blocks, function(v)
    v.action = crops[v.name] and crops[v.name].action

    if v.action == 'bash' then
      return v.y == 0
    end
    if v.action == 'drop' then
      return doDropOff and v.y == -1
    end
    if v.action == 'smash' then
      return v.y == -1
    end
    return v.action == 'plant' and
      v.metadata == crops[v.name].mature and
      v.y == -1
  end)

  local harvestCount = 0
  for _,v in pairs(blocks) do
    if v.action ~= 'drop' then
      harvestCount = harvestCount + 1
    end
  end

  return blocks, harvestCount
end

local function harvest(blocks)
  turtle.equip('right', 'minecraft:diamond_pickaxe')
  turtle.setPoint({ x = 0, y = 0, z = 0, heading = turtle.point.heading })
  turtle.select(1)

  local dropped

  Point.eachClosest(turtle.point, blocks, function(b)
    if b.action == 'bash' then
      turtle.digForwardAt(b)
    elseif b.action == 'drop' and not dropped then
      if turtle._goto(Point.above(b)) then
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
      turtle.digDownAt(b)
    elseif b.action == 'plant' then
      if turtle.digDownAt(b) then
        turtle.placeDown(crops[b.name].seed)
        turtle.select(1)
      end
    end
  end)
  turtle.equip('right', 'plethora:module:2')
end

turtle.run(function()
  local facing = scanner.getBlockMeta(0, 0, 0).state.facing
  turtle.point.heading = Point.facings[facing].heading

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
