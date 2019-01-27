local class      = require('class')
local itemDB     = require('core.itemDB')
local Peripheral = require('peripheral')
local Util       = require('util')

local os = _G.os

local ChestAdapter = class()

local convertNames = {
  name = 'id',
  damage = 'dmg',
  maxCount = 'max_size',
  count = 'qty',
  displayName = 'display_name',
  maxDamage = 'max_dmg',
  nbtHash = 'nbt_hash',
}

-- Strip off color prefix
local function safeString(text)

  local val = text:byte(1)

  if val < 32 or val > 128 then

    local newText = {}
    for i = 4, #text do
      val = text:byte(i)
      newText[i - 3] = (val > 31 and val < 127) and val or 63
    end
    return string.char(unpack(newText))
  end

  return text
end

local function convertItem(item)
  for k,v in pairs(convertNames) do
    item[k] = item[v]
    item[v] = nil
  end
  item.displayName = safeString(item.displayName)
end

function ChestAdapter:init(args)
  local defaults = {
    name = 'chest',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local chest
  if not self.side then
    chest = Peripheral.getByMethod('getAllStacks')
  else
    chest = Peripheral.getBySide(self.side)
    if chest and not chest.getAllStacks then
      chest = nil
    end
  end

  if chest then
    Util.merge(self, chest)

    if chest.listAvailableItems then
      self.list = chest.listAvailableItems
    end
  end
end

function ChestAdapter:isValid()
  return not not self.getAllStacks
end

function ChestAdapter:refresh(throttle)
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function ChestAdapter:listItems(throttle)
  local cache = { }
  local items = { }
  throttle = throttle or Util.throttle()

    -- getAllStacks sometimes fails
  local s, m = pcall(function()
    for _,v in pairs(self.getAllStacks(false)) do
      if v.qty > 0 then
        convertItem(v)
        local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

        local entry = cache[key]
        if not entry then
          entry = itemDB:get(v) or itemDB:add(v)
          entry = Util.shallowCopy(entry)
          entry.count = 0
          cache[key] = entry
          table.insert(items, entry)
        end
        entry.count = entry.count + v.count
        throttle()
      end
      itemDB:flush()
    end
  end)
  if s then
    if not Util.empty(items) then
      self.cache = cache
      return items
    end
  else
    _debug(m)
  end
end

function ChestAdapter:getItemInfo(item)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
  return self.cache[key]
end

function ChestAdapter:provide(item, qty, slot, direction)
  pcall(function()
    for key,stack in Util.rpairs(self.getAllStacks(false)) do
      if stack.id == item.name and
        (not item.damage or stack.dmg == item.damage) and
        (not item.nbtHash or stack.nbt_hash == item.nbtHash) then
        local amount = math.min(qty, stack.qty)
        if amount > 0 then
          self.pushItemIntoSlot(direction or self.direction, key, amount, slot)
        end
        qty = qty - amount
        if qty <= 0 then
          break
        end
      end
    end
  end)
end

function ChestAdapter:extract(slot, qty, toSlot)
  if toSlot then
    self.pushItemIntoSlot(self.direction, slot, qty, toSlot)
  else
    self.pushItem(self.direction, slot, qty)
  end
end

function ChestAdapter:insert(slot, qty, toSlot)
  -- toSlot not tested ...
  local s, m = pcall(self.pullItem, self.direction, slot, qty, toSlot)
  if not s and m then
    os.sleep(1)
    pcall(self.pullItem, self.direction, slot, qty, toSlot)
  end
end

return ChestAdapter
