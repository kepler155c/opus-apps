local class      = require('class')
local RSAdapter  = require('refinedAdapter')
local Peripheral = require('peripheral')
local Util       = require('util')

local MEAdapter = class(RSAdapter)

function MEAdapter:init(args)
  local defaults = {
    name    = 'appliedEnergistics',
    jobList = { },
  }
  Util.merge(self, defaults)
  Util.merge(self, args)

  local controller
  if not self.side then
    controller = Peripheral.getByMethod('getCraftingCPUs')
  else
    controller = Peripheral.getBySide(self.side)
    if controller and not controller.getCraftingCPUs then
      controller = nil
    end
  end

  if controller then
    Util.merge(self, controller)
  end
end

function MEAdapter:isValid()
  return not not self.getCraftingCPUs
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

function MEAdapter:craft(item, qty)
  if not self:isCPUAvailable() then
    return false
  end

  local detail = self.findItem(item)
  if detail and detail.craft then

    local cpus = self.getCraftingCPUs() or { }
    for cpu,v in pairs(cpus) do
      if not v.busy then
        self.requestCrafting({
            id = item.name,
            dmg = item.damage,
            nbt_hash = item.nbtHash,
          },
          count or 1,
          v.name                     -- CPUs must be named ! use anvil
        )

        os.sleep(0) -- needed ?
        cpus = self.getCraftingCPUs() or { }

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

function MEAdapter:isCrafting(item)
  for _,task in pairs(self.getCraftingTasks()) do
    local output = task.getPattern().outputs[1]
    if output.name == item.name and
       output.damage == item.damage and
       output.nbtHash == item.nbtHash then
      return true
    end
  end
  return false
end

return MEAdapter
