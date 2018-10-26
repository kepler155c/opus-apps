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
    remotes = { },
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
    --debug('attach: ' .. dev)
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
    --debug('detach: ' .. dev)
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
debug('Trashcan: none')

  elseif trashcan and device[trashcan.name] then
    if not self.trashcan or (self.trashcan and self.trashcan.name ~= trashcan.name) then
debug('Trashcan: ' .. trashcan.name)
      self.trashcan = device[trashcan.name]
    end
  end
end

function NetworkedAdapter:initStorage(detachedDevice)
  local storage = { }
  local online = true

  -- check to see if any of the storage chests are disconnected
  for k,v in pairs(self.remoteDefaults) do
    if v.mtype == 'storage' then
      if not device[v.name] or v.name == detachedDevice then
        online = false
      else
        storage[k] = v
      end
    end
  end

  debug('Initializing storage')
  debug(storage)

  self.remotes = { }
  for k in pairs(storage) do
    local remote = Peripheral.get({ name = k })
    if remote and remote.size and remote.list then
      local adapter = InventoryAdapter.wrap({ side = k, direction = self.localName })
      if adapter then
        table.insert(self.remotes, adapter)
        Util.merge(remote, self.remoteDefaults[remote.side])
      end
    end
  end

  table.sort(self.remotes, function(a, b)
    if not a.priority then
      return false
    elseif not b.priority then
      return true
    end
    return a.priority > b.priority
  end)

  self:setOnline(online)
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

  for _, remote in pairs(self.remotes) do
    remote:listItems(throttle)
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

function NetworkedAdapter:export(target, slot, count, item)
  return self:provide(item, count, slot, target)
end

function NetworkedAdapter:provide(item, qty, slot, direction)
  local total = 0

  for _, remote in ipairs(self.remotes) do
    local amount = remote:provide(item, qty, slot, direction)
    if amount > 0 then
--debug('EXT: %s(%d): %s -> %s%s',
--  item.name, amount, remote.side, direction or self.localName,
--  slot and string.format('[%d]', slot) or '')
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

function NetworkedAdapter:trash(source, slot, count)
  if not self.trashcan then
    return
  end
debug('TRA: %s[%d] (%d)', source, slot, count)
  return self.trashcan.pullItems(source, slot, count)
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

  local function insert(remote)
    local amount = remote:insert(slot, qty, toSlot, source or self.localName)
    if amount > 0 then
debug('INS: %s(%d): %s[%d] -> %s',
  item.name, amount,
  source or self.localName, slot, remote.side)
      self.dirty = true
      remote.dirty = true
      local entry = self.activity[key] or 0
      self.activity[key] = entry + amount
    end
    qty = qty - amount
    total = total + amount
  end

  -- found a chest locked with this item
  for _, remote in pairs(self.remotes) do
    -- TODO: proper checking using ignore dmg/nbt
    if remote.lock == key or remote.lock == item.name then
      insert(remote)
      if qty > 0 then -- TODO: only if void flag set
        total = total + self:trash(source, slot, qty)
      end
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
