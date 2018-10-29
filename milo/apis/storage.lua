local class            = require('class')
local Event            = require('event')
local InventoryAdapter = require('inventoryAdapter')
local Peripheral       = require('peripheral')
local Util             = require('util')

local device = _G.device
local os     = _G.os

local Storage = class()

function Storage:init(args)
  local defaults = {
    remoteDefaults = { },
    dirty = true,
listCount = 0,
    activity = { },
    storageOnline = true,
    hits = 0,
    misses = 0,
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local modem = Peripheral.get('wired_modem') or error('Wired modem not attached')
  self.localName = modem.getNameLocal()

  Event.on({ 'device_attach', 'device_detach' }, function(e, dev)
debug('%s: %s', e, tostring(dev))
    self:initStorage()
  end)
  Event.onInterval(15, function()
    self:showStorage()
    debug('STORAGE: cache: %d/%d', self.hits, self.misses)
  end)
end

function Storage:showStorage()
  local t = { }
  for k,v in pairs(self.remoteDefaults) do
    local online = v.adapter and v.adapter.online
    if not online then
      table.insert(t, k)
    end
  end
  if #t > 0 then
    debug('Storage:')
    for _, k in pairs(t) do
      debug(' offline: ' .. k)
    end
    debug('')
  end
end

function Storage:setOnline(online)
  if online ~= self.storageOnline then
    self.storageOnline = online
    os.queueEvent(self.storageOnline and 'storage_online' or 'storage_offline', online)
    debug('Storage: %s', self.storageOnline and 'online' or 'offline')
  end
end

function Storage:isOnline()
  return self.storageOnline
end

function Storage:initStorage()
  local online = true

  debug('Initializing storage')
  for k,v in pairs(self.remoteDefaults) do
    if v.adapter then
      v.adapter.online = not not device[k]
    elseif device[k] and device[k].list and device[k].size and device[k].pullItems then
      v.adapter = InventoryAdapter.wrap({ side = k })
      v.adapter.online = true
      v.adapter.dirty = true
    end
    if v.mtype == 'storage' then
      online = online and not not (v.adapter and v.adapter.online)
    end
  end

  self:setOnline(online)
end

function Storage:filterActive(mtype, filter)
  local iter = { }
  for _, v in pairs(self.remoteDefaults) do
    if v.adapter and v.adapter.online and v.mtype == mtype then
      if not filter or filter(v) then
        table.insert(iter, v)
      end
    end
  end

  local i = 0
  return function()
    i = i + 1
    return iter[i]
  end
end

function Storage:onlineAdapters(reversed)
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

function Storage:refresh(throttle)
  self.dirty = true
debug('STORAGE: Forcing full refresh')
  for _, adapter in self:onlineAdapters() do
    adapter.dirty = true
  end
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function Storage:listItems(throttle)
  if not self.dirty then
    return self.items
  end
self.listCount = self.listCount + 1
--debug(self.listCount)

  -- todo: only listItems from dirty remotes
local ct = os.clock()
  local cache = { }
  local items = { }
  throttle = throttle or Util.throttle()

  for _, adapter in self:onlineAdapters() do
    if adapter.dirty then
debug('STORAGE: refresh: ' .. adapter.name)
      adapter:listItems(throttle)
      adapter.dirty = false
    end
    local rcache = adapter.cache or { }
-- TODO: add a method in each adapter that only updates a passed cache
    for key,v in pairs(rcache) do
      local entry = cache[key]
      if not entry then
        entry = Util.shallowCopy(v)
        entry.count = v.count
        entry.key = key
        cache[key] = entry
        table.insert(items, entry)
      else
        entry.count = entry.count + v.count
      end

      throttle()
    end
  end
debug('STORAGE: refresh in ' .. (os.clock() - ct))

  self.dirty = false
  self.cache = cache
  self.items = items
  return items
end

function Storage:export(target, slot, count, item)
  return self:provide(item, count, slot, target)
end

function Storage:provide(item, qty, slot, direction)
  local total = 0

  local key = item.key or table.concat({ item.name, item.damage, item.nbtHash }, ':')
  for _, adapter in self:onlineAdapters() do
    if adapter.cache and adapter.cache[key] then
      local amount = adapter:provide(item, qty, slot, direction or self.localName)
      if amount > 0 then
        self.hits = self.hits + 1
  debug('EXT: %s(%d): %s -> %s%s',
    item.name, amount, adapter.name, direction or self.localName,
    slot and string.format('[%d]', slot) or '')
        self.dirty = true
        adapter.dirty = true
      end
      qty = qty - amount
      total = total + amount
      if qty <= 0 then
        return total
      end
    end
  end

  debug('miss: %s - %d', key, qty)
  self.misses = self.misses + 1

  for _, adapter in self:onlineAdapters() do
    local amount = adapter:provide(item, qty, slot, direction or self.localName)
    if amount > 0 then
debug('EXT: %s(%d): %s -> %s%s',
  item.name, amount, adapter.name, direction or self.localName,
  slot and string.format('[%d]', slot) or '')
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

function Storage:trash(source, slot, count)
  local trashcan = Util.find(self.remoteDefaults, 'mtype', 'trashcan')
  if trashcan and trashcan.adapter and trashcan.adapter.online then
debug('TRA: %s[%d] (%d)', source or self.localName, slot, count or 64)
    return trashcan.adapter.pullItems(source or self.localName, slot, count)
  end
  return 0
end

function Storage:import(source, slot, count, item)
  return self:insert(slot, count, nil, item, source)
end

function Storage:insert(slot, qty, toSlot, item, source)
  local total = 0

  -- toSlot is not really valid with this adapter
  if toSlot then
    error('Storage: toSlot is not valid')
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
  source or self.localName, slot, adapter.name)
      self.dirty = true
      adapter.dirty = true
      local entry = self.activity[key] or 0
      self.activity[key] = entry + amount

--[[
      local cached = adapter.cache[key]
      if cached then
        cached.count = cached.count + amount
      else
      end
]]
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
      if adapter.cache and adapter.cache[key] and not adapter.lock then
        insert(adapter)
      end
    end
  end

  -- high to low priority
  for remote in self:onlineAdapters() do
    if qty <= 0 then
      break
    end
    if not remote.lock then
      insert(remote.adapter)
    end
  end

  return total
end

return Storage
