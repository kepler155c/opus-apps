local itemDB = require('itemDB')
local Milo   = require('milo')

local device = _G.device

local ExportTask = {
	priority = 5,
}

function ExportTask:cycle(context)
	for target, v in pairs(context.config.remoteDefaults) do
		if v.exports then
			local machine = device[target]
			if machine and machine.getItemMeta then
				for _, entry in pairs(v.exports) do
					local slot = machine.getItemMeta(entry.slot) or { count = 0 }
					local maxCount = slot.maxCount or itemDB:getMaxCount(entry.name)
					local count = maxCount - slot.count
					if count > 0 then
						context.inventoryAdapter:provide(
							itemDB:splitKey(entry.name), count, entry.slot, target)
					end
				end
			else
				debug('Invalid export target: ' .. target)
			end
		end
	end
end

Milo:registerTask(ExportTask)
