local itemDB = require('itemDB')
local Milo   = require('milo')

local ExportTask = {
	name = 'exporter',
	priority = 40,
}

local function filter(a)
	return a.exports
end

function ExportTask:cycle(context)
	for machine in context.storage:filterActive('machine', filter) do
		for _, entry in pairs(machine.exports) do
			local slotNo = type(entry.slot) == 'number' and entry.slot or nil -- '*' indicates any slot

			local slot = (slotNo and machine.adapter.getItemMeta(slotNo)) or { count = 0 }
			for key in pairs(entry.filter or { }) do
				local item = itemDB:splitKey(key)

				-- is something else is in this slot
				if not slot.name or slot.name == item.name then
					local maxCount = slot.maxCount or itemDB:getMaxCount(item)
					local count = maxCount - slot.count
					if not slotNo then
						-- TODO: should we just execute export -
						-- or scan all slots for space ??
						count = machine.adapter.size() * maxCount - slot.count
					end
					if count > 0 then
						item = Milo:getItemWithQty(item)
						if item and count > 0 then
							context.storage:export(
								machine.name,
								slotNo,
								math.min(count, item.count),
								item)
						end
					end
				end
			end
		end
	end
end

Milo:registerTask(ExportTask)
