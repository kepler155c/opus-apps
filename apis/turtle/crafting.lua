local Adapter = require('inventoryAdapter')
local Craft   = require('turtle.craft')

local turtle     = _G.turtle

local CRAFTING_TABLE = 'minecraft:crafting_table'

local function clearGrid(inventory)
  for i = 1, 16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      inventory:insert(i, count)
      if turtle.getItemCount(i) ~= 0 then
        return false
      end
    end
  end
  return true
end

function turtle.craftItem(item, count, inventoryInfo)
  local success

  local inventory = Adapter.wrap(inventoryInfo)
  if not inventory then
    return false, 'Invalid inventory'
  end

  local equipped, side
  if not turtle.isEquipped('workbench') then
    local modemSide = turtle.isEquipped('modem') or 'right'
    local osides = { left = 'right', right = 'left' }
    side = osides[modemSide]
    if not turtle.select(CRAFTING_TABLE) then
      clearGrid(inventory)
      if not turtle.selectOpenSlot() then
        return false, 'Inventory is full'
      end
      if not inventory:provide({ name = CRAFTING_TABLE, damage = 0 }, 1) then
        return false, 'Missing crafting table'
      end
    end

    local slot = turtle.select(CRAFTING_TABLE)
    turtle.equip(side, CRAFTING_TABLE)
    equipped = turtle.getItemDetail(slot)
  end

  success = Craft.craftRecipe(item, count or 1, inventory)

  if equipped then
    turtle.selectOpenSlot()
    inventory:provide({ name = equipped.name, damage = equipped.damage }, 1)
    turtle.equip(side, equipped.name .. ':' .. equipped.damage)
  end

  return success
end

function turtle.canCraft(item, count, items)
  return Craft.canCraft(item, count, items)
end

return true
