local itemDB = require('itemDB')
local Milo   = require('milo')

local ReplenishTask = {
  name = 'replenish',
  priority = 70,
}

function ReplenishTask:cycle(context)
  local craftList = { }

  for _,res in pairs(context.resources) do
    if res.low then
      local item = Milo:getItemWithQty(res, res.ignoreDamage, res.ignoreNbtHash)
      if not item then
        item = {
          damage = res.damage,
          nbtHash = res.nbtHash,
          name = res.name,
          displayName = itemDB:getName(res),
          count = 0
        }
      end

      if item.count < res.low then
        if res.ignoreDamage then
          item.damage = 0
        end
        local key = Milo:uniqueKey(res)

        craftList[key] = {
          damage = item.damage,
          nbtHash = item.nbtHash,
          count = res.low - item.count,
          name = item.name,
          displayName = item.displayName,
          status = '',
          rsControl = res.rsControl,
        }
      end
    end
  end

  Milo:craftItems(craftList)
end

Milo:registerTask(ReplenishTask)
