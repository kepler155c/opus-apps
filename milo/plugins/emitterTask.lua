local itemDB = require('core.itemDB')
local Milo   = require('milo')

local device = _G.device

local EmitterTask = {
	name = 'emitter',
	priority = 5,
}

local function filter(a)
	return a.emitter
end

function EmitterTask:cycle(context)
	for node in context.storage:filterActive('emitter', filter) do
		local config = node.emitter
		local item = Milo:getItem(itemDB:splitKey(config.item))

		config.signal = not not config.signal
		if item and item.count >= config.amount then
			device[node.name].setOutput(config.side, config.signal)
		else
			device[node.name].setOutput(config.side, not config.signal)
		end
	end
end

Milo:registerTask(EmitterTask)
