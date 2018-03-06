local nameDB  = require('nameDB')
local TableDB = require('tableDB')
local Util    = require('util')

local itemDB = TableDB({ fileName = 'usr/config/items.db' })

local function safeString(text)
  local val = text:byte(1)

  if val < 32 or val > 128 then

    local newText = { }
    local skip = 0
    for i = 1, #text do
      val = text:byte(i)
      if val == 167 then
        skip = 2
      end
      if skip > 0 then
        skip = skip - 1
      else
        if val >= 32 and val <= 128 then
          newText[#newText + 1] = val
        end
      end
    end
    return string.char(unpack(newText))
  end

  return text
end

function itemDB:makeKey(item)
  return table.concat({ item.name, item.damage or '*', item.nbtHash }, ':')
end

function itemDB:splitKey(key, item)
  item = item or { }

  local t = Util.split(key, '(.-):')
  if #t[#t] > 8 then
    item.nbtHash = table.remove(t)
  end
  local damage = table.remove(t)
  if damage ~= '*' then
    item.damage = tonumber(damage)
  end
  item.name = table.concat(t, ':')

  return item
end

function itemDB:get(key)
  if type(key) == 'string' then
    key = self:splitKey(key)
  end

  local item = TableDB.get(self, self:makeKey(key))
  if item then
    return item
  end

  -- try finding an item that has damage values
  if type(key.damage) == 'number' then
    item = TableDB.get(self, self:makeKey({ name = key.name, nbtHash = key.nbtHash }))
    if item and item.maxDamage then
      item = Util.shallowCopy(item)
      item.damage = key.damage
      if item.maxDamage > 0 and type(item.damage) == 'number' and item.damage > 0 then
        item.displayName = string.format('%s (damage: %s)', item.displayName, item.damage)
      end
      return item
    end
  end

  if not key.damage then
    for k,item in pairs(self.data) do
      if key.name == item.name and
         key.displayName == item.displayName and
         key.nbtHash == key.nbtHash and
         item.maxDamage > 0 then
        item = Util.shallowCopy(item)
        item.nbtHash = key.nbtHash
        return item
      end
    end
  end

  if key.nbtHash then
    item = self:get({ name = key.name, damage = key.damage })

    if item and item.ignoreNBT then
      item = Util.shallowCopy(item)
      item.nbtHash = key.nbtHash
      item.damage = key.damage
      return item
    end
  end
end

--[[
  If the base item contains an NBT hash, then the NBT hash uniquely
  identifies this item.
]]--
function itemDB:add(baseItem)
  local nItem = {
    name    = baseItem.name,
    damage  = baseItem.damage,
    nbtHash = baseItem.nbtHash,
  }
--  if detail.maxDamage > 0 then
--    nItem.damage = '*'
--  end

  nItem.displayName = safeString(baseItem.displayName)
  nItem.maxCount = baseItem.maxCount
  nItem.maxDamage = baseItem.maxDamage

  for k,item in pairs(self.data) do
    if nItem.name == item.name and
       nItem.displayName == item.displayName then

      if nItem.nbtHash ~= item.nbtHash and nItem.damage ~= item.damage then
        nItem.damage = '*'
        nItem.nbtHash = nil
        nItem.ignoreNBT = true
        self.data[k] = nil
        break
      elseif nItem.damage ~= item.damage then
        nItem.damage = '*'
        self.data[k] = nil
        break
      elseif nItem.nbtHash ~= item.nbtHash then
        nItem.nbtHash = nil
        nItem.ignoreNBT = true
        self.data[k] = nil
        break
      end
    end
  end

  TableDB.add(self, self:makeKey(nItem), nItem)
  nItem = Util.shallowCopy(nItem)
  nItem.damage = baseItem.damage
  nItem.nbtHash = baseItem.nbtHash

  return nItem
end

-- Accepts: "minecraft:stick:0" or { name = 'minecraft:stick', damage = 0 }
function itemDB:getName(item)
  if type(item) == 'string' then
    item = self:splitKey(item)
  end

  local detail = self:get(item)
  if detail then
    return detail.displayName
  end

  -- fallback to nameDB
  local strId = self:makeKey(item)
  local name = nameDB.data[strId]
  if not name and not item.damage then
    name = nameDB.data[self:makeKey({ name = item.name, damage = 0, nbtHash = item.nbtHash })]
  end
  return name or strId
end

function itemDB:getMaxCount(item)
  local detail = self:get(item)
  return detail and detail.maxCount or 64
end

function itemDB:load()
  TableDB.load(self)

  for key,item in pairs(self.data) do
    self:splitKey(key, item)
    item.maxDamage = item.maxDamage or 0
    item.maxCount = item.maxCount or 64
  end
end

function itemDB:flush()
  if self.dirty then

    local t = { }
    for k,v in pairs(self.data) do
      v = Util.shallowCopy(v)
      v.name = nil
      v.damage = nil
      v.nbtHash = nil
v.count = nil -- wipe out previously saved counts - temporary
      if v.maxDamage == 0 then
        v.maxDamage = nil
      end
      if v.maxCount == 64 then
        v.maxCount = nil
      end
      t[k] = v
    end

    Util.writeTable(self.fileName, t)
    self.dirty = false
  end
end

itemDB:load()

return itemDB
