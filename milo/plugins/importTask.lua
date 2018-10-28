local Milo = require('milo')

local device = _G.device

local ImportTask = {
	name = 'importer',
	priority = 20,
}

function ImportTask:cycle(context)
	for source, v in pairs(context.config.remoteDefaults) do
		if v.imports then
			local inventory = device[source]
			if inventory then
				for _, entry in pairs(v.imports) do

					local function matchesFilter(item)
						if not entry.filter then
							return true
						end

						local key = Milo:uniqueKey(item)
						if entry.blacklist then
							return not entry.filter[key]
						end
						return entry.filter[key]
					end

					local function importSlot(slotNo)
						local item = inventory.getItemMeta(slotNo)
						if item and matchesFilter(item) then
							context.storage:import(source, slotNo, item.count, item)
						end
					end

					if type(entry.slot) == 'number' then
						importSlot(entry.slot)
					else
						for i = 1, inventory.size() do
							importSlot(i)
						end
					end
				end
			else
				debug('Invalid import source: ' .. source)
			end
		end
	end
end

Milo:registerTask(ImportTask)
