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

			local function exportSlot(list, slotNo, item, count)
				local slot = list[slotNo] or { count = 0 }

				if slot.count == 0 or
					(slot.name == item.name and
					 slot.damage == item.damage and
					 slot.nbtHash == item.nbtHash) then

					local maxCount = itemDB:getMaxCount(item)
					count = math.min(maxCount - slot.count, count)

					if count > 0 then
-- _debug('attempting to export %s %d into slot %d', item.name, count, slotNo)
						count = context.storage:export(machine.name, slotNo, count, item)

						if count > 0 then
							item.count = item.count - count
							list[slotNo] = {
								name = item.name,
								damage = item.damage,
								nbtHash = item.nbtHash,
								count = count + slot.count,
							}
							return true
						end
					end
				end
			end

			local list
			local function getLazyList()
				if not list then
					list = machine.adapter.list()
				end
				return list
			end

			for key in pairs(entry.filter or { }) do
				-- bad for perf to do listItems each time
				local items = Milo:getMatches(Milo:listItems(), itemDB:splitKey(key), entry.ignoreDamage, entry.ignoreNbtHash)
				for _,item in pairs(items) do
					if item and item.count > 0 then
						if type(entry.slot) == 'number' then
							if exportSlot(getLazyList(), entry.slot, item, item.count) then
								break
							end
						else
-- _debug('attempting to export %s %d', item.name, item.count)
-- TODO: always going to try and export even if the chest is full
							context.storage:export(machine.name, nil, item.count, item)
						end
					end
				end
			end
		end
	end
end

Milo:registerTask(ExportTask)
