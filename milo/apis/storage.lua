local Adapter = require('miniAdapter')
local class   = require('class')
local Config  = require('config')
local Event   = require('event')
local itemDB  = require('itemDB')
local sync    = require('sync').sync
local Util    = require('util')

local device   = _G.device
local os       = _G.os
local parallel = _G.parallel

local Storage  = class()

local function loadOld(storage)
  storage.nodes = Config.load('milo', { })

  -- TODO: remove - temporary
  if storage.nodes.remoteDefaults then
    storage.nodes.nodes = storage.nodes.remoteDefaults
    storage.nodes.remoteDefaults = nil
  end

  -- TODO: remove - temporary
  if storage.nodes.nodes then
    local categories = {
      input = 'custom',
      trashcan = 'custom',
      machine = 'machine',
      brewingStand = 'machine',
      activity = 'display',
      jobs = 'display',
      ignore = 'ignore',
      hidden = 'ignore',
      manipulator = 'custom',
      storage = 'storage',
    }
    for _, node in pairs(storage.nodes.nodes) do
      if node.lock and type(node.lock) == 'string' then
        node.lock = {
          [ node.lock ] = true,
        }
      end
      if not node.category then
        node.category = categories[node.mtype]
        if not node.category then
          Util.print(node)
          error('invalid node')
        end
      end
    end
    storage.nodes = storage.nodes.nodes
  end
end

function Storage:init()
  local defaults = {
    dirty = true,
    activity = { },
    storageOnline = true,
  }
  Util.merge(self, defaults)
  self.nodes = Config.load('storage', { })

  if Util.empty(self.nodes) then -- TODO: temporary
    loadOld(self)
  end

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
  local ignores = {
    ignore = true,
    hidden = true,
  }
  for k,v in pairs(self.nodes) do
    local online = v.adapter and v.adapter.online
    if not online and not ignores[v.mtype] then
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
    if v.mtype ~= 'hidden' then
      if v.adapter then
        v.adapter.online = not not device[k]
      elseif device[k] and device[k].list and device[k].size and device[k].pullItems then
        v.adapter = Adapter({ side = k })
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
  end

  if online ~= self.storageOnline then
    self.storageOnline = online
    -- TODO: if online, then list items
    os.queueEvent(self.storageOnline and 'storage_online' or 'storage_offline', online)
    _G._debug('Storage: %s', self.storageOnline and 'online' or 'offline')
  end

  self:listItems()
end

function Storage:saveConfiguration()
  local t = { }
  for k,v  in pairs(self.nodes) do
    t[k] = v.adapter
    v.adapter = nil
  end

  -- TODO: Should be named 'storage'
  Config.update('storage', self.nodes)

  for k,v  in pairs(t) do
    self.nodes[k].adapter = v
  end
  self:initStorage()
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

function Storage:onlineAdapters()
  local iter = { }
  for _, v in pairs(self.nodes) do
    if v.adapter and v.adapter.online and v.mtype == 'storage' then
      table.insert(iter, v)
    end
  end

  table.sort(iter, function(a, b)
    if not a.priority then
      return false
    elseif not b.priority then
      return true
    end
    return a.priority > b.priority
  end)

  local i = 0
  return function()
    i = i + 1
    local a = iter[i]
    if a then
      return a, a.adapter
    end
  end
end

function Storage:setDirty()
  self.dirty = true
end

function Storage:refresh(throttle)
  self.dirty = true
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
  --sync(self, function()
    if not self.dirty then
      return self.cache
    end

    local timer = Timer()
    local cache = { }
    throttle = throttle or Util.throttle()

    local t = { }
    for _, adapter in self:onlineAdapters() do
      if adapter.dirty then
        table.insert(t, function()
          adapter:listItems(throttle)
          adapter.dirty = false
        end)
      end
    end

    if #t > 0 then
      _G._debug('STORAGE: refreshing ' .. #t .. ' inventories')
      parallel.waitForAll(table.unpack(t))
    end

    for _, adapter in self:onlineAdapters() do
      if adapter.dirty then
        _G._debug('STORAGE: refreshing ' .. adapter.name)
        --adapter:listItems(throttle)
        --adapter.dirty = false
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
    itemDB:flush()
    _G._debug('STORAGE: refresh in ' .. timer())

    self.dirty = false
    self.cache = cache
  --end)
  return self.cache
end

function Storage:updateCache(adapter, item, count)
  if not adapter.cache then
    adapter.dirty = true
    self.dirty = true
    return
  end

  local key = item.key or table.concat({ item.name, item.damage, item.nbtHash }, ':')
  local entry = adapter.cache[key]

  if not entry then
    if count < 0 then
      _G._debug('STORAGE: update cache - count < 0', 4)
    else
      entry = Util.shallowCopy(item)
      entry.count = count
      entry.key = key
      adapter.cache[key] = entry
    end
  else
    entry.count = entry.count + count
    if entry.count <= 0 then
      adapter.cache[key] = nil
    end
  end

  if not entry then
    _G._debug('STORAGE: item missing details')
    adapter.dirty = true
    self.dirty = true
  else
    local sentry = self.cache[key]
    if sentry then
      sentry.count = sentry.count + count
      if sentry.count <= 0 then
        self.cache[key] = nil
      end
    elseif count > 0 then
      sentry = Util.shallowCopy(entry)
      sentry.count = count
      self.cache[key] = sentry
    else
      self.dirty = true
    end
  end
end

function Storage:_sn(name)
  if not name then
    error('Invalid target', 3)
  end

  local node = self.nodes[name]
  if node and node.displayName then
    return node.displayName
  end
  local t = { name:match(':(.+)_(%d+)$') }
  if #t ~= 2 then
    return name
  end
  return table.concat(t, '_')
end

local function isValidTransfer(adapter, target)
  for _,v in pairs(adapter.getTransferLocations()) do
    if v == target then
      return true
    end
  end
end

local function rawExport(source, target, item, qty, slot)
  local total = 0
  local push = isValidTransfer(source, target.name)

  local s, m = pcall(function()
    local stacks = source.list()
    for key,stack in Util.rpairs(stacks) do
      if stack.name == item.name and
         stack.damage == item.damage and
         stack.nbtHash == item.nbtHash then
        local amount = math.min(qty, stack.count)
        if amount > 0 then
          if push then
            amount = source.pushItems(target.name, key, amount, slot)
          else
            amount = target.pullItems(source.name, key, amount, slot)
          end
        end
        qty = qty - amount
        total = total + amount
        if qty <= 0 then
          break
        end
      end
    end
  end)

  if not s and m then
    _debug(m)
  end

  return total, m
end

function Storage:export(target, slot, count, item)
  local total = 0
  local key = item.key or table.concat({ item.name, item.damage, item.nbtHash }, ':')

  local function provide(adapter)
    local amount = rawExport(adapter, target.adapter, item, count, slot)
    if amount > 0 then

      _G._debug('EXT: %s(%d): %s -> %s%s',
        item.displayName or item.name, amount, self:_sn(adapter.name), self:_sn(target.name),
        slot and string.format('[%d]', slot) or '[*]')

      self:updateCache(adapter, item, -amount)
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

  _G._debug('MISS: %s(%d): %s%s %s',
    item.displayName or item.name, count, self:_sn(target.name),
    slot and string.format('[%d]', slot) or '[*]', key)

-- TODO: If there are misses when a slot is specified than something is wrong...
-- The caller should confirm the quantity beforehand
-- If no slot and full amount is not exported, then no need to check rest of adapters
-- ... so should not reach here

  return total
end

local function rawInsert(source, target, slot, qty)
  local count = 0

  local s, m = pcall(function()
    if isValidTransfer(source, target.name) then
--_debug('pull %s %s %d %d', source.name, target.name, slot, qty)
      count = source.pullItems(target.name, slot, qty)
    else
--_debug('push %s %s', target.name, source.name)
      count = target.pushItems(source.name, slot, qty)
    end
  end)
  if not s and m then
    _debug(m)
  end

  return count
end

function Storage:import(source, slot, count, item)
  if not source then error('Storage:import: source is required') end
  if not slot   then error('Storage:import: slot is required')   end

  local total = 0
  local key = item.key or table.concat({ item.name, item.damage, item.nbtHash }, ':')

  if not self.cache then
    self:listItems()
  end

  local entry = itemDB:get(key)
  if not entry then
    if item.displayName then
       -- this item already has metadata
      entry = itemDB:add(item)
    else
       -- get the metadata from the device and add to db
      entry = itemDB:add(source.adapter.getItemMeta(slot))
    end
    itemDB:flush()
  end
  item = entry

  local function insert(adapter)
    local amount = rawInsert(adapter, source.adapter, slot, count)
    if amount > 0 then

      _G._debug('INS: %s(%d): %s[%d] -> %s',
        item.displayName or item.name, amount,
        self:_sn(source.name), slot, self:_sn(adapter.name))

      self:updateCache(adapter, item, amount)

      -- record that we have imported this item into storage during this cycle
      self.activity[key] = (self.activity[key] or 0) + amount
    end
    count = count - amount
    total = total + amount
  end

  -- find a chest locked with this item
  for node in self:onlineAdapters() do
    if node.lock and node.lock[key] then
      insert(node.adapter, item)
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
      if not node.lock and adapter.cache and adapter.cache[key] then
        insert(adapter)
      end
    end
  end

  -- high to low priority
  for node in self:onlineAdapters() do
    if count <= 0 then
      break
    end
    if not node.lock then
      insert(node.adapter)
    end
  end

  return total
end

-- When importing items into a locked chest, trash any remaining items if full
function Storage:trash(source, slot, count)
  local target = Util.find(self.nodes, 'mtype', 'trashcan')
  local amount = 0
  if target and target.adapter and target.adapter.online then
    local s, m = pcall(function()
      _G._debug('TRA: %s[%d] (%d)', self:_sn(source.name), slot, count or 64)
      --return trashcan.adapter.pullItems(source.name, slot, count)
      if isValidTransfer(source.adapter, target.name) then
        amount = source.adapter.pushItems(target.name, slot, count)
      else
        amount = target.adapter.pullItems(source.name, slot, count)
      end
    end)
    if not s and m then
      _G._debug(m)
    end
  end
  return amount
end

return Storage
