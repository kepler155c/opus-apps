local Milo = require('milo')

local LimitTask = {
	name = 'limiter',
	priority = 50,
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
				context.storage:export(
					trashcan,
					nil,
					item.count - res.limit,
					item)
			end
		end
	end
end

Milo:registerTask(LimitTask)
