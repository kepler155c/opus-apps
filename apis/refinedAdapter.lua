local class      = require('class')
local Util       = require('util')
local Peripheral = require('peripheral')
local itemDB     = require('itemDB')

local RefinedAdapter = class()

local keys = {
  'damage',
  'displayName',
  'maxCount',
  'maxDamage',
  'name',
  'nbtHash',
}

function RefinedAdapter:init(args)
  local defaults = {
    items = { },
    name = 'refinedStorage',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local controller = Peripheral.getByType('refinedstorage:controller') or
                     Peripheral.getByMethod('listAvailableItems')
  if controller then
    Util.merge(self, controller)
  end
end

function RefinedAdapter:isValid()
  return not not self.listAvailableItems
end

function RefinedAdapter:isOnline()
  return self.getNetworkEnergyStored() > 0
end

function RefinedAdapter:getCachedItemDetails(item)
  local detail = itemDB:get(item)
  if not detail then
    detail = self.findItem(item)
    if detail then
      local meta
      pcall(function() meta = detail.getMetadata() end)
      if not meta then
        return
      end
      Util.merge(detail, meta)

      local t = { }
      for _,k in pairs(keys) do
        t[k] = detail[k]
      end

      detail = t
      itemDB:add(detail)
    end
  end
  if detail then
    return Util.shallowCopy(detail)
  end
end

function RefinedAdapter:listItems()
  local items = { }
  local list

  pcall(function()
    list = self.listAvailableItems()
  end)

  if list then

    local throttle = Util.throttle()

    for _,v in pairs(list) do
      local item = self:getCachedItemDetails(v)
      if item then
        item.count = v.count
        table.insert(items, item)
      end
      throttle()
    end
    itemDB:flush()
  end

  return items
end

function RefinedAdapter:getItemInfo(fingerprint)
  local item = itemDB:get(fingerprint)
  if not item then
    return self:getCachedItemDetails(fingerprint)
  end

  local detail = self.findItem(item)
  if detail then
    item.count = detail.count
    return item
  end
end

function RefinedAdapter:isCrafting(item)
  for _,task in pairs(self.getCraftingTasks()) do
    local output = task.getPattern().outputs[1]
    if output.name == item.name and
       output.damage == item.damage and
       output.nbtHash == item.nbtHash then
      return true
    end
  end
  return false
end

function RefinedAdapter:craft(item, qty)
  local detail = self.findItem(item)
  if detail then
    return detail.craft(qty)
  end
end

function RefinedAdapter:craftItems()
  return false
end

function RefinedAdapter:provide()
end

function RefinedAdapter:extract()
--  self.pushItems(self.direction, slot, qty)
end

function RefinedAdapter:insert()
--  self.pullItems(self.direction, slot, qty)
end

return RefinedAdapter
