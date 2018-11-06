--[[
Use 4 furnaces at once to smelt items.

Set up a turtle with a hopper on top and surrounded by furnaces.

Set the hopper as a machine used for crafting.
Export coal to slot 2 of each furnace and import from slot 3.
--]]

_G.requireInjector(_ENV)

local Event = require('event')
local Util = require('util')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local intro =
  device['plethora:introspection']
local inv = intro.getInventory()

Event.on('turtle_inventory', function()
  while true do
    local list = inv.list()
    local sleepTime = 10
    if Util.empty(list) then
      break
    end
    for k,slot in pairs(list) do
      for _ = 1, 4 do
        local count = 0
        local s, m = pcall(function()
          count = inv.pushItems('front', k, 8, 1)
        end)
        if not s then
          _G.printError(m)
        end
        if count > 0 then
          sleepTime = 0
        end
        turtle.turnRight()
        slot.count = slot.count - count
        if slot.count <= 0 then
          break
        end
      end
    end
    os.sleep(sleepTime)
  end
end)

os.queueEvent('turtle_inventory')
Event.pullEvents()