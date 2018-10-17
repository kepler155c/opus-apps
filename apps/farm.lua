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
    { seed = 'minecraft:wheat_seeds', mature = 7 },
  ['minecraft:carrots'] =
    { seed = 'minecraft:carrot', mature = 7 },
  ['minecraft:potatoes'] =
    { seed = 'minecraft:potato', mature = 7 },
  ['minecraft:beetroots'] =
    { seed = 'minecraft:beetroot_seeds', mature = 3 },
}

if not fs.exists(CONFIG_FILE) then
  Util.writeTable(CONFIG_FILE, crops)
end

local function scan()
  local blocks = scanner.scan()

  Util.filterInplace(blocks, function(v)
    if v.name == 'minecraft:reeds' then
      return v.y == 0
    end
    if v.name == 'minecraft:chest' then
      return v.y == -1
    end
    return crops[v.name] and
      scanner.getBlockMeta(v.x, v.y, v.z).metadata == crops[v.name].mature
  end)

  local harvestCount = 0
  for _,v in pairs(blocks) do
    if v.name ~= 'minecraft:chest' then
      harvestCount = harvestCount + 1
    end
  end

  return blocks, harvestCount
end

local function harvest(blocks)
  turtle.equip('right', 'minecraft:diamond_pickaxe')
  turtle.setPoint({ x = 0, y = 0, z = 0, heading = turtle.point.heading })

  Point.eachClosest(turtle.point, blocks, function(b)
    turtle.select(1)
    if b.name == 'minecraft:reeds' then
      turtle._goto(b)
    elseif b.name == 'minecraft:chest' then
      local summed = turtle.getSummedInventory()
      for _,v in pairs(summed) do
        if v.count > 48 then
          if turtle._goto(Point.above(b)) then
            for k,v2 in pairs(summed) do
              if v2.count > 16 then
                turtle.dropDown(k, v2.count - 16)
              end
            end
          end
          break
        end
      end
    else
      turtle._goto(Point.above(b))
      turtle.digDown()
      turtle.placeDown(crops[b.name].seed)
    end
  end)
  turtle.equip('right', 'plethora:module:2')
end

turtle.run(function()
  local facing = scanner.getBlockMeta(0, 0, 0).state.facing
  turtle.point.heading = Point.facings[facing].heading

  turtle.setPolicy('digOnly')
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
