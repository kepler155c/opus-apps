local GPS = require("gps")
local Point = require("point")
local Util = require("util")

local peripheral = _G.peripheral
local turtle = _G.turtle

local args = {...}
local block = args[1] or error("Syntax: blockMiner [item name]")

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

local function scan()
  equip("left", "plethora:module:2")
  return peripheral.call("left", "scan")
end

if turtle.isEquipped("modem") ~= "right" then
  equip("right", "computercraft:advanced_modem")
end

local pt = GPS.getPoint(2) or error("GPS not found")
equip("left", "plethora:module")
local facing = peripheral.call("left", "getBlockMeta", 0, 0, 0).state.facing
pt.heading = Point.facings[facing].heading
turtle.setPoint(pt, true)
equip("left", "minecraft:diamond_pickaxe")
