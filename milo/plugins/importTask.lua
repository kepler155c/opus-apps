local Milo = require('milo')

local device = _G.device

local ImportTask = {
	name = 'importer',
	priority = 20,
}

function ImportTask:cycle(context)
	for source, v in pairs(context.config.remoteDefaults) do
		if v.imports then
			local inventory = device[source]
			if inventory and inventory.getItemMeta then
				for slot in pairs(v.imports) do
					local item = inventory.getItemMeta(slot)
					if item then
						context.storage:import(source, slot, item.count, item)
					end
				end
			else
				debug('Invalid import source: ' .. source)
			end
		end
	end
end

Milo:registerTask(ImportTask)
