local itemDB = require('core.itemDB')
local Milo   = require('milo')
local Tasks  = require('milo.taskRunner')
local Util   = require('opus.util')

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
					local cache,size={node.adapter.list(),node.adapter.size()} -- Make single calls, not repeat
					local cacheSize=Util.size(cache) -- Same, though this call doesn't hurt as bad
					for key in pairs(entry.filter) do
						local items = Milo:getMatches(itemDB:splitKey(key), entry)
						for _,item in pairs(items) do
							if size ~= cacheSize then
								-- Here we have a storage which has at least 1 unpopulated slot, we can fire'n'forget into this
								if context.storage:export(node, nil, item.count, item) == 0 then
									-- TODO: really shouldn't break here as there may be room in other slots
									-- leaving for now for performance reasons
									break
								end
							else
								-- Here we have a storage with all slots occupied, sort through and find open spaces
								for iNum=1,size do
									local slot = cache[i]
									if slot then
										if (slot.name == item.name and slot.count ~= item.maxCount and
										(entry.ignoreDamage or slot.damage == item.damage) and
										(entry.ignoreNbtHash or slot.nbtHash == item.nbtHash)) then
											-- We found a slot that matches, and is not full, let's export to it!
											-- Reworked to use item's .maxCount against the existing .list()[slot].count instead of repeat .getItemMeta calls
											context.storage:export(node, iNum, math.min(item.maxCount-slot.count,item.count), item)
										end
									end
								end
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
