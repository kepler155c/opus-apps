local itemDB = require('core.itemDB')
local Milo   = require('milo')
local Tasks = require('milo.taskRunner')

local ExportTask = {
	name = 'exporter',
	priority = 40,
}

local function filter(a)
	return a.exports
end

function ExportTask:cycle(context)
	local tasks = Tasks({
		errorMsg = 'EXPORTER error: ',
	})

	for node in context.storage:filterActive('machine', filter) do
		tasks:add(function()
			for _, entry in pairs(node.exports) do

				if not entry.filter then
					-- exports must have a filter
					-- TODO: validate in exportView
					break
				end

				local function exportSingleSlot()
					local slot = node.adapter.getItemMeta(entry.slot)

					if slot and slot.count == slot.maxCount then
						return
					end

					if slot then
						-- something is in the slot, find what we can export
						for key in pairs(entry.filter) do
							local filterItem = itemDB:splitKey(key)
							if (slot.name == filterItem.name and
									(entry.ignoreDamage or slot.damage == filterItem.damage) and
									(entry.ignoreNbtHash or slot.nbtHash == filterItem.nbtHash)) then

								local items = Milo:getMatches(filterItem, entry)
								local _, item = next(items)
								if item then
									local count = math.min(item.count, slot.maxCount - slot.count)
									context.storage:export(node, entry.slot, count, item)
								end
								break
							end
						end
						return
					end

					-- slot is empty - export first matching item we have in storage
					for key in pairs(entry.filter) do
						local items = Milo:getMatches(itemDB:splitKey(key), entry)
						local _, item = next(items)
						if item then
							local count = math.min(item.count, itemDB:getMaxCount(item))
							context.storage:export(node, entry.slot, count, item)
							break
						end
					end
				end

				local function exportItems()
					for key in pairs(entry.filter) do
						local items = Milo:getMatches(itemDB:splitKey(key), entry)
						for _,item in pairs(items) do
							if context.storage:export(node, nil, item.count, item) == 0 then
								-- TODO: really shouldn't break here as there may be room in other slots
								-- leaving for now for performance reasons
								break
							end
						end
					end
				end
				if type(entry.slot) == 'number' then
					exportSingleSlot()
				else
					exportItems()
				end
			end
		end)
	end

	tasks:run()
end

Milo:registerTask(ExportTask)
