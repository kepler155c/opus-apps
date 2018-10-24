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
					local item = itemDB:splitKey(entry.name)

					-- is something else is in this slot
					if not slot.name or slot.name == item.name then
						local maxCount = slot.maxCount or itemDB:getMaxCount(item)
						local count = maxCount - slot.count

						if count > 0 then
							item = Milo:getItemWithQty(item)
							if item and count > 0 then
								context.inventoryAdapter:provide(
									itemDB:splitKey(entry.name),
									math.min(count, item.count),
									entry.slot,
									target)
							end
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
