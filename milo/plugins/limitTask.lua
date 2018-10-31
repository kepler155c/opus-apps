local Milo = require('milo')

local LimitTask = {
	name = 'limiter',
	priority = 50,
}

function LimitTask:cycle(context)
	local trashcan = context.storage:filterActive('trashcan')()

	if trashcan then
		for k,res in pairs(context.resources) do
			if res.limit then
-- TODO: change to export method of finding items (maybe)
				local item, count = Milo:getItemWithQty(Milo:splitKey(k), res.ignoreDamage, res.ignoreNbtHash)
				if item and count > res.limit then
					context.storage:export(
						trashcan.name,
						nil,
						count - res.limit,
						item)
				end
			end
		end
	end
end

Milo:registerTask(LimitTask)
