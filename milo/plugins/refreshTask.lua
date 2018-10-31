local Milo = require('milo')

-- Do a full scan of inventories every minute

local RefreshTask = {
	name = 'refresher',
	priority = 0,
}

function RefreshTask:cycle(context)
	if os.clock() - context.storage.lastRefresh > 60 then
		context.storage:refresh()
	end
end

Milo:registerTask(RefreshTask)
