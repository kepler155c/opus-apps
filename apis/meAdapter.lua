local class      = require('class')
local itemDB     = require('itemDB')
local Peripheral = require('peripheral')
local Util       = require('util')

local os         = _G.os
local peripheral = _G.peripheral

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

local MEAdapter = class()

function MEAdapter:init(args)
  local defaults = {
    items = { },
    name = 'ME',
    jobList = { },
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local chest

  if not self.side then
    chest = Peripheral.getByMethod('getAvailableItems')
  else
    chest = Peripheral.getBySide(self.side)
    if chest and not chest.getAvailableItems then
      chest = nil
    end
  end

  if chest then
    Util.merge(self, chest)
  end
end

function MEAdapter:isValid()
  return self.getAvailableItems and self.getAvailableItems()
end

function MEAdapter:refresh()

  self.items = self.getAvailableItems('all')
  for _,v in pairs(self.items) do
    Util.merge(v, v.item)
    convertItem(v)

    if not itemDB:get(v) then
      itemDB:add(v, v)
    end
  end
  itemDB:flush()

  return self.items
end

function MEAdapter:listItems()
  self:refresh()
  return self.items
end

function MEAdapter:getItemInfo(item)
   for _,i in pairs(self.items) do
    if item.name == i.name and item.damage == i.damage and item.nbtHash == i.nbtHash then
      return i
    end
  end
end

function MEAdapter:isCPUAvailable()
  local cpus = self.getCraftingCPUs() or { }
  local available = false

  for cpu,v in pairs(cpus) do
    if not v.busy then
      available = true
    elseif not self.jobList[cpu] then -- something else is crafting something (don't know what)
      return false                  -- return false since we are in an unknown state
    end
  end
  return available
end

function MEAdapter:craft(item, count)

  if not self:isCPUAvailable() then
    return false
  end

  self:refresh()

  item = self:getItemInfo(item)
  if item and item.is_craftable then

    local cpus = self.getCraftingCPUs() or { }
    for cpu,v in pairs(cpus) do
      if not v.busy then
        self.requestCrafting({
            id = item.name,
            dmg = item.damage,
            nbt_hash = item.nbtHash,
          },
          count or 1,
          cpu
        )

        os.sleep(0) -- tell it to craft, yet it doesn't show busy - try waiting a cycle...
        cpus = self.getCraftingCPUs() or { }
        if not cpus[cpu].busy then
          -- print('sleeping again')
          os.sleep(.1) -- sigh
          cpus = self.getCraftingCPUs() or { }
        end

        -- not working :(
        if cpus[cpu].busy then
          self.jobList[cpu] = {
            name = item.name,
            damage = item.damage,
            nbtHash = item.nbtHash,
            count = count,
          }
          return true
        end
        break -- only need to try the first available cpu
      end
    end
    return false
  end
end

function MEAdapter:getJobList()
  local cpus = self.getCraftingCPUs() or { }
  for cpu,v in pairs(cpus) do
    if not v.busy then
      self.jobList[cpu] = nil
    end
  end

  return self.jobList
end

function MEAdapter:isCrafting(item)
  for _,v in pairs(self:getJobList()) do
    if v.name == item.name and
       v.damage == item.damage and
       v.nbtHash == item.nbtHash then
      return true
    end
  end
end

function MEAdapter:craftItems(items)
  local cpus = self.getCraftingCPUs() or { }
  local count = 0

  for _,cpu in pairs(cpus) do
    if cpu.busy then
      return
    end
  end

  for _,item in pairs(items) do
    if count >= #cpus then
      break
    end
    if not self:isCrafting(item) then
      if self:craft(item, item.count) then
        count = count + 1
      end
    end
  end
end

function MEAdapter:provide(item, count, slot, direction)
  return pcall(function()
    while count > 0 do
      local qty = math.min(count, 64)
      local s = self.exportItem({
        id = item.name,
        dmg = item.damage
      }, direction or self.direction, qty, slot)

      if not s or s.size ~= qty then
        break
      end
      count = count - 64
    end
  end)
end

function MEAdapter:insert(slot, count)
  local s, m = pcall(function() self.pullItem(self.direction, slot, count) end)
  if not s and m then
    os.sleep(1)
    s, m = pcall(function() self.pullItem(self.direction, slot, count) end)
    if not s and m then
      error(m)
    end
  end
end

return MEAdapter
