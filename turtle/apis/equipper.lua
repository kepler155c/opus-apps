local peripheral = _G.peripheral
local turtle     = _G.turtle

local Equipper = { }

local SCANNER_EQUIPPED = 'plethora:scanner'
local SCANNER_INV      = 'plethora:module:2'

local reversed = {
  left = 'right',
  right = 'left'
}

local function getEquipped()
  Equipper.equipped = { }
  Equipper.equipped.left = peripheral.getType('left')
  Equipper.equipped.right = peripheral.getType('right')

  if not Equipper.equipped.left or not Equipper.equipped.right then
    -- try to detect non-peripheral type items - such as minecraft:diamond_pickaxe
    local side = Equipper.isEquipped(SCANNER_EQUIPPED)
    local meta
    if side then
      meta = peripheral.call(side, 'getBlockMeta', 0, 0, 0)

    elseif turtle.has(SCANNER_INV) then
      local swapSide = peripheral.getType('right') == 'modem' and 'left' or 'right'
      turtle.equip(swapSide, SCANNER_INV)
      meta = peripheral.call(swapSide, 'getBlockMeta', 0, 0, 0)
    end

    if meta then
      if not Equipper.equipped.left then
        Equipper.equipped.left = meta.turtle.left and meta.turtle.left.id
      end
      if not Equipper.equipped.right then
        Equipper.equipped.right = meta.turtle.right and meta.turtle.right.id
      end

    elseif not Equipper.equipped.left then
      local slot = Equipper.uneqip('left')
      if slot then
        Equipper.equipped.left = slot.name .. ':'  .. slot.damage
      end

    elseif not Equipper.equipped.right then
      local slot = Equipper.uneqip('right')
      if slot then
        Equipper.equipped.right = slot.name .. ':'  .. slot.damage
      end
    end
  end
  _debug("Detected Equipped")
  _debug(Equipper.equipped)
end

function Equipper.unequip(side)
  local slot = turtle.selectOpenSlot()
  if not slot then
    error('No slots available')
  end
  turtle.equip(side)
  Equipper.equipped[side] = nil
  return turtle.getItemDetail(slot)
end

function Equipper.isEquipped(name)
  if not Equipper.equipped then
    getEquipped()
  end

  return Equipper.equipped.left  == name and 'left' or
         Equipper.equipped.right == name and 'right'
end

function Equipper.equip(side, invName, equippedName)
  if not Equipper.equipped then
    getEquipped()
  end

  -- is it already equipped ?
  if Equipper.equipped[side] == (equippedName or invName) then
    return
  end
  -- is it equipped on other side ?
  if Equipper.equipped[reversed[side]] == (equippedName or invName) then
    Equipper.unequip(reversed[side])
  end

  local s, m = turtle.equip(side, invName)
  if not s then
    error(string.format('Unable to equip %s\n%s', (equippedName or invName), m))
  end

  Equipper.equipped[side] = peripheral.getType(side) or invName

  _debug("Equipped: " .. invName)
  _debug(Equipper.equipped)
end

function Equipper.equipLeft(invName, equippedName)
  Equipper.equip('left', invName, equippedName)
end

function Equipper.equipRight(invName, equippedName)
  Equipper.equip('right', invName, equippedName)
end

return Equipper
