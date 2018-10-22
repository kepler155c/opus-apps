local itemDB = require('itemDB')
local Lora   = require('lora/lora')

local device = _G.device

local ExportTask = {
	priority = 5,
}

function ExportTask:cycle(context)
	for target, v in pairs(context.config.remoteDefaults) do
		if v.exports then
			local machine = device[target]
			if machine and machine.getItemMeta then
				for slotNo, item in pairs(v.exports) do
					local slot = machine.getItemMeta(slotNo) or { count = 0 }
					local maxCount = slot.maxCount or itemDB:getMaxCount(item)
					local count = maxCount - slot.count
					if count > 0 then
						context.inventoryAdapter:provide(itemDB:splitKey(item), count, slotNo, target)
					end
				end
			else
				debug('Invalid export target: ' .. target)
			end
		end
  end
end

Lora:registerTask(ExportTask)
