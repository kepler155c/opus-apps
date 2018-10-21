local class      = require('class')
local Util       = require('util')
local InventoryAdapter  = require('inventoryAdapter')
local Peripheral = require('peripheral')

local NetworkedAdapter = class()

function NetworkedAdapter:init(args)
  local defaults = {
    name = 'Networked Adapter',
    remotes = { },
    remoteDefaults = { },
    dirty = true,
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  if not self.side or self.side == 'network' then
    self.modem = Peripheral.get('wired_modem')

    if self.modem and self.modem.getNameLocal then
      self.localName = self.modem.getNameLocal()

      for k in pairs(self.remoteDefaults) do
        local remote = Peripheral.get({ name = k })
        if remote and remote.size and remote.list then
          local adapter = InventoryAdapter.wrap({ side = k, direction = self.localName })
          if adapter then
            table.insert(self.remotes, adapter)
          end
        end
      end
    end

    for _, remote in pairs(self.remotes) do
      Util.merge(remote, self.remoteDefaults[remote.side])
    end

    table.sort(self.remotes, function(a, b)
      if not a.priority then
        return false
      elseif not b.priority then
        return true
      end
      return a.priority < b.priority
    end)
  end

_G._p = self  --------------------------------------------- DEBUG
end

function NetworkedAdapter:isValid()
  return #self.remotes > 0
end

function NetworkedAdapter:refresh(throttle)
  self.dirty = true
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function NetworkedAdapter:listItems(throttle)
  if not self.dirty then
    return self.items
  end

  local cache = { }
  local items = { }
  throttle = throttle or Util.throttle()

  for _, remote in pairs(self.remotes) do
    if not remote:listItems(throttle) then
      debug('no List')
      error('Listing failed: ', remote.name)
    end
    local rcache = remote.cache or { }

-- TODO: add a method in each adapter that only updates a passed cache
    for key,v in pairs(rcache) do
      if v.count > 0 then
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

  self.dirty = false
  self.cache = cache
  self.items = items
  return items
end

function NetworkedAdapter:getItemInfo(item)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
  local items = self.cache or { }
  return items[key]
end

function NetworkedAdapter:provide(item, qty, slot, direction)
  local total = 0

  for _, remote in ipairs(self.remotes) do
debug('%s -> slot %d: %d %s', remote.side, slot or -1, qty, item.name)
    local amount = remote:provide(item, qty, slot, direction)
    if amount > 0 then
      self.dirty = true
      remote.dirty = true
    end
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

function NetworkedAdapter:insert(slot, qty, toSlot, item)
  local total = 0

  -- toSlot is not really valid with this adapter
  if toSlot then
    error('NetworkedAdapter: toSlot is not valid')
  end

  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')

  if not self.cache then
    self:listItems()
  end

debug('attempting to insert ' .. item.name)

  local function insert(remote)
debug('slot %d -> %s: %s', slot, remote.side, qty)
    local amount = remote:insert(slot, qty, toSlot)
    if amount > 0 then
      self.dirty = true
      remote.dirty = true
    end
    qty = qty - amount
    total = total + amount
  end

  -- found a chest locked with this item
  for _, remote in pairs(self.remotes) do
    if remote.lockWith == key or remote.lockWith == item.name then
      insert(remote)
      return total
    end
  end

  if self.cache[key] then -- is this item in some chest
    -- low to high priority if the chest already contains that item
    for _, remote in Util.rpairs(self.remotes) do
      if qty <= 0 then
        break
      end
      if remote.cache and remote.cache[key] and not remote.lockWith then
        insert(remote)
      end
    end
  end

  -- high to low priority
  for _, remote in ipairs(self.remotes) do
    if qty <= 0 then
      break
    end
    if not remote.lockWith then
      insert(remote)
    end
  end

  return total
end

return NetworkedAdapter
