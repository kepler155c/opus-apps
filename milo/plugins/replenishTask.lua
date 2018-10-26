local itemDB = require('itemDB')
local Milo   = require('milo')

local ReplenishTask = {
  name = 'replenish',
  priority = 60,
}

function ReplenishTask:cycle(context)
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
        Milo:requestCrafting({
          damage = item.damage,
          nbtHash = item.nbtHash,
          count = res.low - item.count,
          name = item.name,
          displayName = item.displayName,
          replenish = true,
        })
      else
        local request = context.craftingQueue[Milo:uniqueKey(item)]
        if request and request.replenish then
          request.count = request.crafted
        end
      end
    end
  end
end

Milo:registerTask(ReplenishTask)
