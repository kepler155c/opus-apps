local Milo = require('milo')

-- Do a full scan of inventories every minute

local RefreshTask = {
	name = 'refresher',
	priority = 0,
}

function RefreshTask:cycle(context)
	local now = os.clock()

	 for node, adapter in context.storage:onlineAdapters() do
		if node.refreshInterval then
			if not adapter.lastRefresh or adapter.lastRefresh + node.refreshInterval < now then
				_G._debug('REFRESHER: ' .. adapter.name)
				context.storage.dirty = true
				adapter.dirty = true
				adapter.lastRefresh = now
			end
		end
	end

--	if os.clock() - context.storage.lastRefresh > 60 then
--		context.storage:refresh()
--	end
end

Milo:registerTask(RefreshTask)
