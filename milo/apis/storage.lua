local class            = require('class')
local Event            = require('event')
local InventoryAdapter = require('inventoryAdapter')
local Peripheral       = require('peripheral')
local Util             = require('util')

local device = _G.device
local os     = _G.os

local NetworkedAdapter = class()

function NetworkedAdapter:init(args)
  local defaults = {
    remoteDefaults = { },
    dirty = true,
listCount = 0,
    activity = { },
    storageOnline = true,
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local modem = Peripheral.get('wired_modem') or error('Wired modem not attached')
  self.localName = modem.getNameLocal()

  Event.on({ 'device_attach' }, function(_, dev)
    if self.remoteDefaults[dev] then
      if self.remoteDefaults[dev].mtype == 'storage' then
        self:initStorage()
      end
      if self.remoteDefaults[dev].mtype == 'trashcan' then
        self:initTrashcan()
      end
    end
  end)

  Event.on({ 'device_detach' }, function(_, dev)
    if self.remoteDefaults[dev] then
      if self.remoteDefaults[dev].mtype == 'storage' then
        self:initStorage(dev)
      end
      if self.remoteDefaults[dev].mtype == 'trashcan' then
        self:initTrashcan(dev)
      end
    end
  end)
end

function NetworkedAdapter:setOnline(online)
  if online ~= self.storageOnline then
    self.storageOnline = online
    os.queueEvent(self.storageOnline and 'storage_online' or 'storage_offline')
    debug('Storage: %s', self.storageOnline and 'online' or 'offline')
  end
end

function NetworkedAdapter:isOnline()
  return self.storageOnline
end

function NetworkedAdapter:initTrashcan(detachedDevice)
  local trashcan = Util.find(self.remoteDefaults, 'mtype', 'trashcan')

  if (detachedDevice and self.trashcan and self.trashcan.name == detachedDevice) or
     (trashcan and not device[trashcan.name]) then
    self.trashcan = nil
debug(' Trashcan: none')

  elseif trashcan and device[trashcan.name] then
    if not self.trashcan or (self.trashcan and self.trashcan.name ~= trashcan.name) then
debug(' Trashcan: ' .. trashcan.name)
      self.trashcan = device[trashcan.name]
    end
  end
end

function NetworkedAdapter:initStorage()
  local online = true

  debug('Initializing storage')
  for k,v in pairs(self.remoteDefaults) do
    if v.adapter then
      v.adapter.online = not not device[k]
      if v.mtype == 'storage' then
        online = online and v.adapter.online
      end
    elseif v.mtype == 'storage' then
      v.adapter = InventoryAdapter.wrap({ side = k })
      v.adapter.online = true
    end
    if v.mtype == 'storage' then
      debug('  %s: %s', v.adapter.online and ' online' or 'offline', k)
    end
  end

  self:setOnline(online)
end

function NetworkedAdapter:onlineAdapters(reversed)
  local iter = { }
  for _, v in pairs(self.remoteDefaults) do
    if v.adapter and v.adapter.online and v.mtype == 'storage' then
      table.insert(iter, v)
    end
  end

  local function forwardSort(a, b)
    if not a.priority then
      return false
    elseif not b.priority then
      return true
    end
    return a.priority > b.priority
  end

  local function backwardSort(a, b)
    return not forwardSort(a, b)
  end

  table.sort(iter, reversed and backwardSort or forwardSort)

  local i = 0
  return function()
    i = i + 1
    local a = iter[i]
    if a then
      return a, a.adapter
    end
  end
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
self.listCount = self.listCount + 1
--debug(self.listCount)

  -- todo: only listItems from dirty remotes

  local cache = { }
  local items = { }
  throttle = throttle or Util.throttle()

  for _, adapter in self:onlineAdapters() do
    adapter:listItems(throttle)
    local rcache = adapter.cache or { }

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

function NetworkedAdapter:export(target, slot, count, item)
  return self:provide(item, count, slot, target)
end

function NetworkedAdapter:provide(item, qty, slot, direction)
  local total = 0

  for _, adapter in self:onlineAdapters() do
    local amount = adapter:provide(item, qty, slot, direction)
    if amount > 0 then
--debug('EXT: %s(%d): %s -> %s%s',
--  item.name, amount, remote.side, direction or self.localName,
--  slot and string.format('[%d]', slot) or '')
      self.dirty = true
      adapter.dirty = true
    end
    qty = qty - amount
    total = total + amount
    if qty <= 0 then
      break
    end
  end

  return total
end

function NetworkedAdapter:trash(source, slot, count)
  if self.trashcan then
  debug('TRA: %s[%d] (%d)', source, slot, count)
    return self.trashcan.pullItems(source, slot, count)
  end
  return 0
end

function NetworkedAdapter:import(source, slot, count, item)
  return self:insert(slot, count, nil, item, source)
end

function NetworkedAdapter:insert(slot, qty, toSlot, item, source)
  local total = 0

  -- toSlot is not really valid with this adapter
  if toSlot then
    error('NetworkedAdapter: toSlot is not valid')
  end

  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')

  if not self.cache then
    self:listItems()
  end

  local function insert(adapter)
    local amount = adapter:insert(slot, qty, toSlot, source or self.localName)
    if amount > 0 then
debug('INS: %s(%d): %s[%d] -> %s',
  item.name, amount,
  source or self.localName, slot, adapter.side)
      self.dirty = true
      adapter.dirty = true
      local entry = self.activity[key] or 0
      self.activity[key] = entry + amount
    end
    qty = qty - amount
    total = total + amount
  end

  -- find a chest locked with this item
  for remote in self:onlineAdapters() do
    -- TODO: proper checking using ignore dmg/nbt
    if remote.lock == key or remote.lock == item.name then
      insert(remote.adapter)
      if qty > 0 then -- TODO: only if void flag set
        total = total + self:trash(source, slot, qty)
      end
      return total
    end
  end

  if self.cache[key] then -- is this item in some chest
    -- low to high priority if the chest already contains that item
    for _, adapter in self:onlineAdapters(true --[[ reversed ]]) do
      if qty <= 0 then
        break
      end
      if adapter.cache and adapter.cache[key] and not adapter.lockWith then
        insert(adapter)
      end
    end
  end

  -- high to low priority
  for remote in self:onlineAdapters() do
    if qty <= 0 then
      break
    end
    if not remote.lockWith then
      insert(remote.adapter)
    end
  end

  return total
end

return NetworkedAdapter
