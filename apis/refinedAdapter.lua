local class      = require('class')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')
local Util       = require('util')

local RefinedAdapter = class()

function RefinedAdapter:init(args)
  local defaults = {
    name = 'refinedStorage',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local controller
  if not self.side then
    controller = Peripheral.getByMethod('listAvailableItems')
  else
    controller = Peripheral.getBySide(self.side)
    if controller and not controller.listAvailableItems then
      controller = nil
    end
  end

  if controller then
    Util.merge(self, controller)
  end
end

function RefinedAdapter:isValid()
  return not not self.listAvailableItems
end

function RefinedAdapter:getItemDetails(item)
  local detail = self.findItems(item)
  if detail and #detail > 0 then
    return detail[1].getMetadata()
  end
end

function RefinedAdapter:getCachedItemDetails(item)
  local cached = itemDB:get(item)
  if cached then
    return cached
  end

  local detail = self:getItemDetails(item)
  if detail then
    return itemDB:add(detail)
  end
end

function RefinedAdapter:refresh(throttle)
  return self:listItems(throttle)
end

function RefinedAdapter:listItems(throttle)
  local items = { }
  throttle = throttle or Util.throttle()

  local s, m = pcall(function()
    for _,v in pairs(self.listAvailableItems()) do
      --if v.count > 0 then
        local item = self:getCachedItemDetails(v)
        if item then
          item = Util.shallowCopy(item)
          item.count = v.count
          table.insert(items, item)
        end
      --end
      throttle()
    end
  end)

  if not s and m then
    debug(m)
  end

  itemDB:flush()
  if not Util.empty(items) then
    return items
  end
end

function RefinedAdapter:getItemInfo(item)
  return self:getItemDetails(item)
end

function RefinedAdapter:isCPUAvailable()
  return true
end

function RefinedAdapter:craft(item, qty)
  local detail = self.findItem(item)
  if detail then
    return detail.craft(qty)
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

function RefinedAdapter:provide(item, qty, slot, direction)
  return pcall(function()
    for _,stack in pairs(self.listAvailableItems()) do
      if stack.name == item.name and
        (not item.damage or stack.damage == item.damage) and
        (not item.nbtHash or stack.nbtHash == item.nbtHash) then
        local amount = math.min(qty, stack.count)
        if amount > 0 then
          local detail = self.findItem(item)
          if detail then
            return detail.export(direction or self.direction, amount, slot)
          end
        end
        qty = qty - amount
        if qty <= 0 then
          break
        end
      end
    end
  end)
end

function RefinedAdapter:extract(slot, qty, toSlot)
  self.pushItems(self.direction, slot, qty, toSlot)
end

function RefinedAdapter:insert(slot, qty, toSlot)
  self.pullItems(self.direction, slot, qty, toSlot)
end

return RefinedAdapter
