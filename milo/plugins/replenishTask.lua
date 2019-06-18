local itemDB = require('core.itemDB')
local Milo   = require('milo')

local ReplenishTask = {
	name = 'replenish',
	priority = 60,
}

function ReplenishTask:cycle(context)
	for k,res in pairs(context.resources) do
		if res.low then
			local item = itemDB:splitKey(k)
			item.key = k

			local _, count = Milo:getMatches(item, res)

			if count < res.low then
				local nbtHash
				if not res.ignoreNbtHash then
					nbtHash = item.nbtHash
				end
				Milo:requestCrafting({
					name = item.name,
					damage = res.ignoreDamage and 0 or item.damage,
					nbtHash = nbtHash,
					requested = res.low - count,
					count = count,
					replenish = true,
				})
			else
				local request = context.craftingQueue[itemDB:makeKey(item)]
				if request and request.replenish then
					--request.count = request.crafted
				end
			end
		end
	end
end

Milo:registerTask(ReplenishTask)
