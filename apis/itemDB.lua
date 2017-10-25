local nameDB  = require('nameDB')
local TableDB = require('tableDB')
local Util    = require('util')

local itemDB = TableDB({ fileName = 'usr/config/items.db' })

function itemDB:makeKey(item)
  return { item.name, item.damage, item.nbtHash }
end

function itemDB:splitKey(key, item)
  item = item or { }

  local t = Util.split(key, '(.-):')
  if #t[#t] > 8 then
    item.nbtHash = table.remove(t)
  end
  item.damage = tonumber(table.remove(t))
  item.name = table.concat(t, ':')

  return item
end

function itemDB:get(key)
  local item = TableDB.get(self, key)

  if item then
    return item
  end

  if key[2] ~= 0 then
    item = TableDB.get(self, { key[1], 0, key[3] })
    if item and item.maxDamage > 0 then
      item = Util.shallowCopy(item)
      item.damage = key[2]
      item.displayName = string.format('%s (damage: %d)', item.displayName, item.damage)
      return item
    end
  end
end

function itemDB:add(key, item)
  if item.maxDamage > 0 then
    key = { key[1], 0, key[3] }
  end
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
  return nameDB:getName(item.name .. ':' .. item.damage)
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
