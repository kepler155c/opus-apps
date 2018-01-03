local class      = require('class')
local Util       = require('util')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')

local ChestAdapter = class()

local keys = Util.transpose({
  'damage',
  'displayName',
  'maxCount',
  'maxDamage',
  'name',
  'nbtHash',
})

function ChestAdapter:init(args)
  local defaults = {
    name      = 'chest',
    direction = 'up',
    wrapSide  = 'bottom',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local chest
  if self.autoDetect then
    chest = Peripheral.getByMethod('list')
  else
    chest = Peripheral.getBySide(self.wrapSide)
    if chest and not chest.list then
      chest = nil
    end
  end

  if chest then
    Util.merge(self, chest)

    local sides = {
      top = 'down',
      bottom = 'up',
    }

    self.direction = sides[self.side] or self.direction
  end
end

function ChestAdapter:isValid()
  return not not self.list
end

function ChestAdapter:getCachedItemDetails(item, k)
  local detail = itemDB:get(item)
  if not detail then
    local s, m = pcall(function() detail = self.getItemMeta(k) end)
    if not detail then
--      error('Inventory has changed')
      return
    end
-- NOT SUFFICIENT
    if detail.name ~= item.name then
--      error('Inventory has changed')
      return
    end

    for _,k in ipairs(Util.keys(detail)) do
      if not keys[k] then
        detail[k] = nil
      end
    end

    itemDB:add(detail)
  end
  if detail then
    return Util.shallowCopy(detail)
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

function ChestAdapter:craft()
end

function ChestAdapter:craftItems()
end

function ChestAdapter:getPercentUsed()
  if self.cache then
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
  if not s then
    debug(m)
  end
  return s, m
end

function ChestAdapter:eject(item, qty, direction)
  local s, m = pcall(function()
    local stacks = self.list()
    local maxStack = itemDB:getMaxCount(item)
    for key,stack in Util.rpairs(stacks) do
      if stack.name == item.name and
        (not item.damage or stack.damage == item.damage) and
        (not item.nbtHash or stack.nbtHash == item.nbtHash) then
        local amount = math.min(maxStack, math.min(qty, stack.count))
debug({ key, amount })
debug(stack)
        if amount > 0 then
          self.drop(key, amount, direction)
        end
        qty = qty - amount
        if qty <= 0 then
          break
        end
      end
    end
  end)
  if not s then
    debug(m)
  end
  return s, m
end

function ChestAdapter:extract(slot, qty, toSlot)
  self.pushItems(self.direction, slot, qty, toSlot)
end

function ChestAdapter:insert(slot, qty)
  self.pullItems(self.direction, slot, qty)
end

return ChestAdapter
