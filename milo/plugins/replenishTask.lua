local itemDB = require('itemDB')
local Milo   = require('milo')

local ReplenishTask = {
  name = 'replenish',
  priority = 60,
}

function ReplenishTask:cycle(context)
  for k,res in pairs(context.resources) do
    if res.low then
      local key = Milo:splitKey(k)
      local item, count = Milo:getItemWithQty(key, res.ignoreDamage, res.ignoreNbtHash)
      if not item then
        item = {
          damage = key.damage,
          nbtHash = key.nbtHash,
          name = key.name,
          displayName = itemDB:getName(key),
          count = 0
        }
      end

      if count < res.low then
        local nbtHash = item.nbtHash
        if res.ignoreNbtHash then
          nbtHash = nil
        end
        Milo:requestCrafting({
          damage = res.ignoreDamage and 0 or item.damage,
          nbtHash = nbtHash,
          count = res.low - count,
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
