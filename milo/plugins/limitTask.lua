local Milo = require('milo')

local LimitTask = {
	name = 'limiter',
	priority = 50,
}

function LimitTask:cycle(context)
	local trashcan = context.storage:filterActive('trashcan')()

	if trashcan then
		for _,res in pairs(context.resources) do
			if res.limit then
				local item = Milo:getItemWithQty(res, res.ignoreDamage, res.ignoreNbtHash)
				if item and item.count > res.limit then
					context.storage:export(
						trashcan.name,
						nil,
						item.count - res.limit,
						item)
				end
			end
		end
	end
end

Milo:registerTask(LimitTask)
