local class      = require('class')
local Util       = require('util')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')

local ChestAdapter = class()

function ChestAdapter:init(args)
  local defaults = {
    name = 'chest',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local chest
  if not self.side then
    chest = Peripheral.getByMethod('list') or
            Peripheral.getByMethod('listAvailableItems')
  else
    chest = Peripheral.getBySide(self.side)
    if chest and not chest.list and not chest.listAvailableItems then
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
  return not not self.list
end

-- handle both AE/RS and generic inventory
function ChestAdapter:getItemDetails(index, item)
  if self.getItemMeta then
    local s, detail = pcall(self.getItemMeta, index)
    if not s or not detail or detail.name ~= item.name then
  --    debug({ s, detail })
      return
    end
    return detail
  else
    local detail = self.findItems(item)
    if detail and #detail > 0 then
      return detail[1].getMetadata()
    end
  end
end

function ChestAdapter:getCachedItemDetails(item, k)
  local cached = itemDB:get(item)
  if cached then
    return cached
  end

  local detail = self:getItemDetails(k, item)
  if detail then
    return itemDB:add(detail)
  end
end

function ChestAdapter:refresh(throttle)
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function ChestAdapter:listItems(throttle)
  local cache = { }
  local items = { }
  throttle = throttle or Util.throttle()

  for k,v in pairs(self.list()) do
    if v.count > 0 then
      local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

      local entry = cache[key]
      if not entry then
        entry = self:getCachedItemDetails(v, k)
        if not entry then
          return -- Inventory has changed
        end
        entry = Util.shallowCopy(entry)
        entry.count = 0
        cache[key] = entry
        table.insert(items, entry)
      end

      if entry then
        entry.count = entry.count + v.count
      end
      throttle()
    end
  end
  itemDB:flush()

  if not Util.empty(items) then
    self.cache = cache
    return items
  end
end

function ChestAdapter:getItemInfo(item)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
  return self.cache[key]
end

function ChestAdapter:getPercentUsed()
  if self.cache and self.getDrawerCount then
    return math.floor(Util.size(self.cache) / self.getDrawerCount() * 100)
  end
  return 0
end

function ChestAdapter:provide(item, qty, slot, direction)
  local s, m = pcall(function()
    local stacks = self.list()
    for key,stack in Util.rpairs(stacks) do
      if stack.name == item.name and
        (not item.damage or stack.damage == item.damage) and
        (not item.nbtHash or stack.nbtHash == item.nbtHash) then
        local amount = math.min(qty, stack.count)
        if amount > 0 then
          self.pushItems(direction or self.direction, key, amount, slot)
        end
        qty = qty - amount
        if qty <= 0 then
          break
        end
      end
    end
  end)
  return s, m
end

function ChestAdapter:extract(slot, qty, toSlot)
  self.pushItems(self.direction, slot, qty, toSlot)
end

function ChestAdapter:insert(slot, qty, toSlot)
  self.pullItems(self.direction, slot, qty, toSlot)
end

return ChestAdapter
