local itemDB = require('core.itemDB')
local Milo   = require('milo')

local LimitTask = {
	name = 'limiter',
	priority = 50,
}

function LimitTask:cycle(context)
	local trashcan = context.storage:filterActive('trashcan')()

	if trashcan then
		for key,res in pairs(context.resources) do
			if res.limit then
				local items, count = Milo:getMatches(itemDB:splitKey(key), res)
				if count > res.limit then
					local amount = count - res.limit
					for _, item in pairs(items) do
						amount = amount - context.storage:export(
							trashcan,
							nil,
							math.min(amount, item.count),
							item)
						if amount <= 0 then
							break
						end
					end
				end
			end
		end
	end
end

Milo:registerTask(LimitTask)
