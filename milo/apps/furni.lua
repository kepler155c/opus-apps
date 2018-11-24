--[[
Use 4 furnaces at once to smelt items.

SETUP:
  Place an introspection module into the turtles inventory.
  Connect with wired modem at bottom of turtle.
  Place furnaces on each side EXCEPT for bottom and right.

CONFIGURATION:
  Set turtle as a "Generic Inventory"
  export coal to slot 2
  import from slot 3

Use this turtle for machine crafting.
--]]

_G.requireInjector(_ENV)

local Event      = require('event')
local Peripheral = require('peripheral')
local Util       = require('util')

local device     = _G.device
local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local function equip(side, item, rawName)
  local equipped = Peripheral.lookup('side/' .. side)

  if equipped and equipped.type == item then
    return true
  end

  if not turtle.equip(side, rawName or item) then
    if not turtle.selectSlotWithQuantity(0) then
      error('No slots available')
    end
    turtle.equip(side)
    if not turtle.equip(side, item) then
      error('Unable to equip ' .. item)
    end
  end

  turtle.select(1)
end

equip('left', 'plethora:introspection', 'plethora:module:0')
local intro = device['plethora:introspection']
local inv = intro.getInventory()
local sides = { 'front', 'back', 'right', 'top' }

-- slot 1: item to cook
-- slot 2: fuel
-- slot 3: return

local active = false

local function process(list)
  active = false

  for _, side in ipairs(Util.shallowCopy(sides)) do
    local f = peripheral.call(side, 'list')

    -- items to cook
    local item = list[1]
    local cooking = f[1]

    if cooking or item then
      active = true
    end

    if item and item.count > 0 then
      if not cooking or cooking.name == item.name then
        local count = cooking and cooking.count or 0
        if count < 64 then
          print('cooking : ' .. side)
          count = inv.pushItems(side, 1, 8, 1)
          item.count = item.count - count
          Util.removeByValue(sides, side)
          table.insert(sides, side)
        end
      end
    end

    -- fuel
    local fuel = f[2] or { count = 0 }
    if fuel.count < 8 then
      print('fueling ' ..side)
      inv.pushItems(side, 2, 8 - fuel.count, 2)
    end

    local result = f[3]
    if result then
      if not list[3] or result.name == list[3].name then
        print('pulling from : ' .. side)
        inv.pullItems(side, 3, result.count, 3)
        list[3] = result
      end
    end
  end

  return active
end

Event.on('turtle_inventory', function()
  print('processing')
  while true do
    -- furnace block updates can cause errors
    local s = pcall(process, inv.list())
    if s and not active then
      break
    end
    os.sleep(3)
  end
  print('idle')
end)

os.queueEvent('turtle_inventory')
Event.pullEvents()
