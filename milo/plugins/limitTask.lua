local Milo = require('milo')

local LimitTask = {
	priority = 10,
}

function LimitTask:cycle(context)
	local trashcan

	for k,v in pairs(context.config.remoteDefaults) do
		if v.mtype == 'trashcan' then
			trashcan = k
			break
		end
	end

	if not trashcan then
		return
	end

	for _,res in pairs(context.resources) do
		if res.limit then
			local item = Milo:getItemWithQty(res, res.ignoreDamage, res.ignoreNbtHash)
			if item and item.count > res.limit then
				context.inventoryAdapter:provide(
					{ name = item.name, damage = item.damage, nbtHash = item.nbtHash },
					item.count - res.limit,
					nil,
					trashcan)
			end
		end
	end
end

Milo:registerTask(LimitTask)
