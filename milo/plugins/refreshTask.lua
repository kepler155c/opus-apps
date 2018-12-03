local Milo = require('milo')

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
end

Milo:registerTask(RefreshTask)
