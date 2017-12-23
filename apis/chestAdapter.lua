local class      = require('class')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')
local Util       = require('util')

local ChestAdapter = class()

local convertNames = {
  name = 'id',
  damage = 'dmg',
  maxCount = 'max_size',
  count = 'qty',
  displayName = 'display_name',
  maxDamage = 'max_dmg',
}
local keys = {
  'damage',
  'displayName',
  'maxCount',
  'maxDamage',
  'name',
  'nbtHash',
}

-- Strip off color prefix
local function safeString(text)

  local val = text:byte(1)

  if val < 32 or val > 128 then

    local newText = {}
    for i = 4, #text do
      val = text:byte(i)
      newText[i - 3] = (val > 31 and val < 127) and val or 63
    end
    return string.char(unpack(newText))
  end

  return text
end

local function convertItem(item)
  for k,v in pairs(convertNames) do
    item[k] = item[v]
    item[v] = nil
  end
  item.displayName = safeString(item.displayName)
end

function ChestAdapter:init(args)
  local defaults = {
    name      = 'chest',
    direction = 'up',
    wrapSide  = 'bottom',
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local chest = Peripheral.getBySide(self.wrapSide)
  if not chest then
    chest = Peripheral.getByMethod('getAllStacks')
  end
  if chest then
    Util.merge(self, chest)
  end
end

function ChestAdapter:isValid()
  return not not self.getAllStacks
end

function ChestAdapter:refresh(throttle)
  return self:listItems(throttle)
end

-- provide a consolidated list of items
function ChestAdapter:listItems(throttle)
  self.cache = { }

  for _,v in pairs(self.getAllStacks(false)) do
    convertItem(v)
    local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

    local entry = self.cache[key]
    if not entry then
      self.cache[key] = v

      if not itemDB:get(v) then
        local t = { }
        for _,k in pairs(keys) do
          t[k] = v[k]
        end
        itemDB:add(t)
      end
    else
      entry.count = entry.count + v.count
    end
  end
  itemDB:flush()
  return self.cache
end

function ChestAdapter:getItemInfo(item)
  if not self.cache then
    self:listItems()
  end
  local key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
  return self.cache[key]
end

function ChestAdapter:craft()
end

function ChestAdapter:craftItems()
end

function ChestAdapter:provide(item, qty, slot, direction)
  for key,stack in pairs(self.getAllStacks(false)) do
    if stack.id == item.name and
       stack.dmg == item.damage and
       stack.nbt_hash == item.nbtHash then

      local amount = math.min(qty, stack.qty)
      self.pushItemIntoSlot(direction or self.direction, key, amount, slot)
      qty = qty - amount
      if qty <= 0 then
        break
      end
    end
  end
end

function ChestAdapter:extract(slot, qty, toSlot)
  if toSlot then
    self.pushItemIntoSlot(self.direction, slot, qty, toSlot)
  else
    self.pushItem(self.direction, slot, qty)
  end
end

function ChestAdapter:insert(slot, qty)
  local s, m = pcall(function() self.pullItem(self.direction, slot, qty) end)
  if not s and m then
    os.sleep(1)
    pcall(function() self.pullItem(self.direction, slot, qty) end)
  end
end

return ChestAdapter
