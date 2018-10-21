local class      = require('class')
local Util       = require('util')
local InventoryAdapter  = require('inventoryAdapter')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')

local NetworkedAdapter = class()

function NetworkedAdapter:init(args)
  local defaults = {
    name = 'Networked Adapter',
    remotes = { },
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  if not self.side or self.side == 'network' then
    self.chests = { }
    self.modem = Peripheral.get('wired_modem')

    if self.modem and self.modem.getNameLocal then
      self.localName = self.modem.getNameLocal()
      for _, v in pairs(self.modem.getNamesRemote()) do
        local remote = Peripheral.get({ name = v })
        if remote and remote.size and remote.size() >= 27 and remote.list then

          local adapter = InventoryAdapter.wrap({ side = v, direction = self.localName })
          if adapter then
            table.insert(self.remotes, adapter)
          end
        end
      end
    end
  end

  _G._p = self
end

function NetworkedAdapter:isValid()
  return #self.remotes > 0
end

function NetworkedAdapter:refresh(throttle)
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function NetworkedAdapter:listItems(throttle)
  local cache = { }
  local items = { }
  throttle = throttle or Util.throttle()

  for _, v in pairs(self.remotes) do
    v.__cache = v:listItems(throttle)

    for k,v in pairs(v.__cache) do
      if v.count > 0 then
        local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

        local entry = cache[key]
        if not entry then
          entry = Util.shallowCopy(v)
          entry.count = v.count
          cache[key] = entry
          table.insert(items, entry)
        else
          entry.count = entry.count + v.count
        end

        throttle()
      end
    end
  end

  if not Util.empty(items) then
    self.cache = cache
    return items
  end
end

function NetworkedAdapter:getItemInfo(item)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
  local items = self.cache or { }
  return items[key]
end

function NetworkedAdapter:getPercentUsed()
  if self.cache and self.getDrawerCount then
    return math.floor(Util.size(self.cache) / self.getDrawerCount() * 100)
  end
  return 0
end

function NetworkedAdapter:provide(item, qty, slot, direction)
  local total = 0

  for _, remote in pairs(self.remotes) do
debug('%s -> slot %d: %d %s', remote.side, slot, qty, item.name)
    local amount = remote:provide(item, qty, slot)
    qty = qty - amount
    total = total + amount
    if qty <= 0 then
      break
    end
  end

  return total
end

function NetworkedAdapter:extract(slot, qty, toSlot)

  error('extract not supported')
  local total = 0
  for _, remote in pairs(self.remotes) do
debug('extract %d slot:%d', qty, slot)
    local amount = remote:extract(slot, qty, toSlot)
    qty = qty - amount
    total = total + amount
    if qty <= 0 then
      break
    end
  end

  return total
end

function NetworkedAdapter:insert(slot, qty, toSlot)
  local total = 0
  for _, remote in pairs(self.remotes) do
debug('slot %d -> %s: %s', slot, remote.side, qty)
    local amount = remote:insert(slot, qty, toSlot)
    qty = qty - amount
    total = total + amount
    if qty <= 0 then
      break
    end
  end

  return total
end

return NetworkedAdapter
