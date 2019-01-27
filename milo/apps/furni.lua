--[[
Use multiple furnaces at once to smelt items.

SETUP:
  Place an introspection module into the turtles inventory.
  Connect turtle to milo network with a wired modem.
  Connect turtle to a second wired modem that is connected to furnaces ONLY.
  Add as many furnaces as needed.

CONFIGURATION:
  Set turtle as a "Generic Inventory"
  export coal to slot 2
  import from slot 3

Use this turtle for machine crafting.
--]]

local Event      = require('event')
local Peripheral = require('peripheral')
local Util       = require('util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/miloFurni.lua'

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

if not fs.exists(STARTUP_FILE) then
  Util.writeFile(STARTUP_FILE,
    [[os.sleep(1)
shell.openForegroundTab('packages/milo/apps/furni')]])
end

local furni
local localName

print('detecting wired modem connected to furnaces...')
for _, dev in pairs(device) do
  if dev.type == 'wired_modem' then
    local list = dev.getNamesRemote()
    furni = { }
    localName = dev.getNameLocal()
    for _, name in pairs(list) do
      if device[name].type ~= 'minecraft:furnace' then
        furni = nil
        break
      end
      table.insert(furni, device[name])
    end
  end
  if furni then
    print('Using wired modem: '  .. dev.name)
    print('Furnaces: ' .. #furni)
    break
  end
end

if not furni then
  error('Turtle must be connected to a second wired_modem connected to furnaces only')
end

_G.printError([[Program must be restarted if new furnaces are added.]])

-- slot 1: item to cook
-- slot 2: fuel
-- slot 3: return

local active = false

local function process(list)
  active = false

  for _, furnace in ipairs(Util.shallowCopy(furni)) do
    local f = furnace.list()

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
          print('cooking : ' .. furnace.name)
          count = furnace.pullItems(localName, 1, 8, 1)
          item.count = item.count - count
          Util.removeByValue(furni, furnace)
          table.insert(furni, furnace)
        end
      end
    end

    -- fuel
    local fuel = f[2] or { count = 0 }
    if fuel.count < 8 then
      print('fueling ' ..furnace.name)
      furnace.pullItems(localName, 2, 8 - fuel.count, 2)
    end

    local result = f[3]
    if result then
      if not list[3] or result.name == list[3].name then
        print('pulling from : ' .. furnace.name)
        furnace.pushItems(localName, 3, result.count, 3)
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
    local s, m = pcall(process, inv.list())
    if s and not active then
      break
    end
    if not s and m then
      _G.printError(m)
    end
    os.sleep(3)
  end
  print('idle')
end)

Event.onInterval(5, function()
  -- for some reason, it keeps stalling ...
  os.queueEvent('turtle_inventory')
end)

os.queueEvent('turtle_inventory')
Event.pullEvents()
