local Milo = require('milo')

local device = _G.device

local ImportTask = {
	priority = 3,
}

function ImportTask:cycle(context)
	for source, v in pairs(context.config.remoteDefaults) do
		if v.imports then
			local machine = device[source]
			if machine and machine.getItemMeta then
				for slotNo in pairs(v.imports) do
					local slot = machine.getItemMeta(slotNo)
					if slot then
						context.inventoryAdapter:insert(slotNo, slot.count, nil, slot, source)
					end
				end
			else
				debug('Invalid import source: ' .. source)
			end
		end
	end
end

Milo:registerTask(ImportTask)
