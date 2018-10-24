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

					-- something else is in this slot
					if slot.count > 0 and slot.name ~= entry.name then
						count = 0
					end
					if count > 0 then
						local item = Milo:getItemWithQty(entry)
						if item.count > 0 then
							context.inventoryAdapter:provide(
								itemDB:splitKey(entry.name),
								math.min(count, item.count),
								entry.slot,
								target)
						end
					end
				end
			else
				debug('Invalid export target: ' .. target)
			end
		end
	end
end

Milo:registerTask(ExportTask)
