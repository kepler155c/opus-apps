local itemDB = require('itemDB')
local Milo   = require('milo')

local device = _G.device

local ExportTask = {
	name = 'exporter',
	priority = 40,
}

function ExportTask:cycle(context)
	for target, v in pairs(context.config.remoteDefaults) do
		if v.exports then
			local machine = device[target]
			if machine and machine.getItemMeta then
				for _, entry in pairs(v.exports) do
					local slotNo = type(entry.slot) == 'number' and entry.slot or nil -- '*' indicates any slot

					local slot = (slotNo and machine.getItemMeta(slotNo)) or { count = 0 }
					for key in pairs(entry.filter) do
						local item = itemDB:splitKey(key)

						-- is something else is in this slot
						if not slot.name or slot.name == item.name then
							local maxCount = slot.maxCount or itemDB:getMaxCount(item)
							local count = maxCount - slot.count
							if not slotNo then
								-- TODO: should we just execute export -
								-- or scan all slots for space ??
								count = machine.size() * maxCount - slot.count
							end
							if count > 0 then
								item = Milo:getItemWithQty(item)
								if item and count > 0 then
									context.storage:export(
										target,
										slotNo,
										math.min(count, item.count),
										item)
								end
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
