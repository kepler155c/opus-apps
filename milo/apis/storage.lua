local class            = require('class')
local Event            = require('event')
local InventoryAdapter = require('inventoryAdapter')
local itemDB           = require('itemDB')
local Peripheral       = require('peripheral')
local Util             = require('util')

local device = _G.device
local os     = _G.os

local Storage = class()

function Storage:init(args)
  local defaults = {
    nodes = { },
    dirty = true,
    activity = { },
    storageOnline = true,
    lastRefresh = os.clock(),
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local modem = Peripheral.get('wired_modem') or error('Wired modem not attached')
  self.localName = modem.getNameLocal()

  Event.on({ 'device_attach', 'device_detach' }, function(e, dev)
_G._debug('%s: %s', e, tostring(dev))
    self:initStorage()
  end)
  Event.onInterval(15, function()
    self:showStorage()
  end)
end

function Storage:showStorage()
  local t = { }
  for k,v in pairs(self.nodes) do
    local online = v.adapter and v.adapter.online
    if not online and v.mtype ~= 'ignore' then
      table.insert(t, k)
    end
  end
  if #t > 0 then
    _G._debug('Adapter:')
    for _, k in pairs(t) do
      _G._debug(' offline: ' .. k)
    end
    _G._debug('')
  end
end

function Storage:isOnline()
  return self.storageOnline
end

function Storage:initStorage()
  local online = true

  _G._debug('Initializing storage')
  for k,v in pairs(self.nodes) do
    if v.adapter then
      v.adapter.online = not not device[k]
    elseif device[k] and device[k].list and device[k].size and device[k].pullItems then
      v.adapter = InventoryAdapter.wrap({ side = k })
      v.adapter.online = true
      v.adapter.dirty = true
    elseif device[k] then
      v.adapter = device[k]
      v.adapter.online = true
    end
    if v.mtype == 'storage' then
      online = online and not not (v.adapter and v.adapter.online)
    end
  end

  if online ~= self.storageOnline then
    self.storageOnline = online
    -- TODO: if online, then list items
    os.queueEvent(self.storageOnline and 'storage_online' or 'storage_offline', online)
    _G._debug('Storage: %s', self.storageOnline and 'online' or 'offline')
  end
end

function Storage:getSingleNode(mtype)
  local node = Util.find(self.nodes, 'mtype', mtype)
  if node and node.adapter and node.adapter.online then
    return node
  end
end

function Storage:filterNodes(mtype, filter)
  local iter = { }
  for _, v in pairs(self.nodes) do
    if v.mtype == mtype then
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

function Storage:filterActive(mtype, filter)
  return self:filterNodes(mtype, function(v)
    if v.adapter and v.adapter.online then
      return not filter and true or filter(v)
    end
  end)
end

function Storage:onlineAdapters(reversed)
  local iter = { }
  for _, v in pairs(self.nodes) do
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
  self.lastRefresh = os.clock()
_G._debug('STORAGE: Forcing full refresh')
  for _, adapter in self:onlineAdapters() do
    adapter.dirty = true
  end
  return self:listItems(throttle)
end

local function Timer()
  local ct = os.clock()
  return function()
    return os.clock() - ct
  end
end

-- provide a consolidated list of items
function Storage:listItems(throttle)
  if not self.dirty then
    return self.cache
  end

-- TODO: is there any reason now to maintain 2 lists
  local cache = { }
  throttle = throttle or Util.throttle()

  local timer = Timer()
  for _, adapter in self:onlineAdapters() do
    if adapter.dirty then
      _G._debug('STORAGE: refreshing ' .. adapter.name)
      adapter:listItems(throttle)
      adapter.dirty = false
    end
    local rcache = adapter.cache or { }
    for key,v in pairs(rcache) do
      local entry = cache[key]
      if not entry then
        entry = Util.shallowCopy(v)
        entry.count = v.count
        entry.key = key
        cache[key] = entry
      else
        entry.count = entry.count + v.count
      end

      throttle()
    end
  end
_G._debug('STORAGE: refresh in ' .. timer())

  self.dirty = false
  self.cache = cache
  return cache
end

function Storage:updateCache(adapter, key, count)
  if not adapter.cache then
    adapter.dirty = true
    self.dirty = true
    return
  end

  local entry = adapter.cache[key]

  if not entry then
    if count < 0 then
      adapter.dirty = true
      self.dirty = true
    else
      -- TODO: all items imported should be updated in itemdb
      -- error here if not
      local item = itemDB:get(key)
      if item then
        entry = Util.shallowCopy(item)
        entry.count = count
        entry.key = key
        adapter.cache[key] = entry
      else
_G._debug('STORAGE: item missing details')
        -- TODO: somehow update itemdb with this maybe new item
        adapter.dirty = true
        self.dirty = true
      end
    end
  else
    entry.count = entry.count + count
    if entry.count <= 0 then
      adapter.cache[key] = nil
    end
  end
end

local function sn(name)
  local t = { name:match(':(.+)_(%d+)$') }
  if #t ~= 2 then
    return name
  end
  return table.concat(t, '_')
end

function Storage:export(target, slot, count, item)
  local total = 0
  local key = item.key or table.concat({ item.name, item.damage, item.nbtHash }, ':')

  local function provide(adapter)
    local amount = adapter:provide(item, count, slot, target)
    if amount > 0 then

  _G._debug('EXT: %s(%d): %s -> %s%s',
    item.displayName or item.name, amount, sn(adapter.name), sn(target),
    slot and string.format('[%d]', slot) or '')

      self:updateCache(adapter, key, -amount)
      self:updateCache(self, key, -amount)
    end
    count = count - amount
    total = total + amount
  end

  -- request from adapters with this item
  for _, adapter in self:onlineAdapters() do
    if adapter.cache and adapter.cache[key] then
      provide(adapter)
      if count <= 0 then
        return total
      end
    end
  end

  _G._debug('STORAGE: MISS: %s - %d', key, count)

  -- not found - scan all others
  for _, adapter in self:onlineAdapters() do
    if not adapter.cache or not adapter.cache[key] then
      provide(adapter)
      if count <= 0 then
  _G._debug('STORAGE: FOUND: %s - %d', key, count)
        break
      end
    end
  end

  return total
end

function Storage:import(source, slot, count, item)
  local total = 0
  local key = item.key or table.concat({ item.name, item.damage, item.nbtHash }, ':')

  if not self.cache then
    self:listItems()
  end

  local function insert(adapter)
    local amount = adapter:insert(slot, count, nil, source)
    if amount > 0 then

_G._debug('INS: %s(%d): %s[%d] -> %s',
  item.displayName or item.name, amount,
  sn(source), slot, sn(adapter.name))

      self:updateCache(adapter, key, amount)
      self:updateCache(self, key, amount)

      -- record that we have imported this item into storage during this cycle
      self.activity[key] = (self.activity[key] or 0) + amount
    end
    count = count - amount
    total = total + amount
  end

  -- find a chest locked with this item
  for node in self:onlineAdapters() do
    if node.lock and node.lock[key] then
      insert(node.adapter)
      if count > 0 and node.void then
        total = total + self:trash(source, slot, count)
        return total
      end
      --return total
    end
    if count <= 0 then
      return total
    end
  end

  -- is this item in some chest
  if self.cache[key] then
    for node, adapter in self:onlineAdapters() do
      if count <= 0 then
        return total
      end
      if adapter.cache and adapter.cache[key] and not node.lock then
        insert(adapter)
      end
    end
  end

  if not itemDB:get(item) then
    if not slot then
      _G._debug("IMPORT: NO SLOT")
    elseif not device[source] or not device[source].getItemMeta then
      _G._debug("IMPORT: DEVICE? : " .. source)
    else
      itemDB:add(device[source].getItemMeta(slot))
    end
  end

  -- high to low priority
  for remote in self:onlineAdapters() do
    if count <= 0 then
      break
    end
    if not remote.lock then
      insert(remote.adapter)
    end
  end

  return total
end

-- When importing items into a locked chest, trash any remaining items if full
function Storage:trash(source, slot, count)
  local trashcan = Util.find(self.nodes, 'mtype', 'trashcan')
  if trashcan and trashcan.adapter and trashcan.adapter.online then

_G._debug('TRA: %s[%d] (%d)', sn(source), slot, count or 64)

    return trashcan.adapter.pullItems(source, slot, count)
  end
  return 0
end

return Storage
