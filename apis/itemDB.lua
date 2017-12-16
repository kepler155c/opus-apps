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
  return { item.name, item.damage, item.nbtHash }
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
    key = self:makeKey(self:splitKey(key))
  end

  local item = TableDB.get(self, key)

  if item then
    return item
  end

  if not key[2] or key[2] ~= 0 then
    item = TableDB.get(self, { key[1], 0, key[3] })
    if item and item.maxDamage > 0 then
      item = Util.shallowCopy(item)
      item.damage = key[2]
      item.displayName = string.format('%s (damage: %s)', item.displayName, (item.damage or '*'))
      return item
    end
  end

  if not key[3] then
    for _,item in pairs(self.data) do
      if item.name == key[1] and
        item.damage == key[2] and
        item.nbtHash then
        item = Util.shallowCopy(item)
        item.nbtHash = nil
        return item
      end
    end
  end
end

function itemDB:add(key, item)
  if item.maxDamage > 0 then
    key = { key[1], 0, key[3] }
  end
  item.displayName = safeString(item.displayName)
  TableDB.add(self, key, item)
end

-- Accepts: "minecraft:stick:0" or { name = 'minecraft:stick', damage = 0 }
function itemDB:getName(item)
  if type(item) == 'string' then
    item = self:splitKey(item)
  end

  local detail = self:get(self:makeKey(item))
  if detail then
    return detail.displayName
  end

  -- fallback to nameDB
  return nameDB:getName(item.name .. ':' .. (item.damage or '*'))
end

function itemDB:getMaxCount(item)
  if type(item) == 'string' then
    item = self:splitKey(item)
  end

  local detail = self:get(self:makeKey(item))
  if detail then
    return detail.maxCount
  end

  return 64
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
