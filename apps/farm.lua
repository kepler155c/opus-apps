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

local crops = Util.readFile(CONFIG_FILE) or {
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
    return crops[v.name] and
      scanner.getBlockMeta(v.x, v.y, v.z).metadata == crops[v.name].mature
    end)

  return blocks
end

local function harvest(blocks)
  turtle.equip('right', 'minecraft:diamond_pickaxe')
  turtle.setPoint({ x = 0, y = 0, z = 0, heading = turtle.point.heading })

  Point.eachClosest(turtle.point, blocks, function(b)
    Util.print(b)
    if b.name == 'minecraft:reeds' then
      turtle._goto(b)
    else
      turtle._goto(Point.above(b))
      turtle.digDown()
      turtle.placeDown(crops[b.name].seed)
      turtle.select(1)
    end
  end)

  turtle.equip('right', 'plethora:module:2')
end

local function dropOff()
  local blocks = scanner.scan()
  local done

  Util.filterInplace(blocks, function(v)
    if v.name == 'minecraft:chest' then
      return v.y == -1
    end
  end)

  turtle.setPoint({ x = 0, y = 0, z = 0, heading = turtle.point.heading })
  Point.eachClosest(turtle.point, blocks, function(b)
    if not done then
      if turtle._goto(Point.above(b)) then
        for k,v in pairs(turtle.getSummedInventory()) do
          if v.count > 32 then
            turtle.dropDown(k, v.count - 32)
          end
          done = true
        end
      end
    end
  end)
end

turtle.run(function()
  local facing = scanner.getBlockMeta(0, 0, 0).state.facing
  turtle.point.heading = Point.facings[facing].heading

  turtle.setPolicy('digOnly')

  repeat
    local blocks = scan()
    if #blocks > 0 then
      turtle.setStatus('Harvesting')
      harvest(blocks)
      turtle.setStatus('Storing')
      dropOff()
      turtle.setStatus('Sleeping')
    end
    os.sleep(10)
  until turtle.isAborted()
end)
