local Milo = require('milo')

local ImportTask = {
	name = 'importer',
	priority = 20,
}

local function filter(a)
	return a.imports
end

-- TODO: ignore damage/nbt

function ImportTask:cycle(context)
	for inventory in context.storage:filterActive('machine', filter) do
		for _, entry in pairs(inventory.imports) do

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
				local item = inventory.adapter.getItemMeta(slotNo)
				if item and matchesFilter(item) then
					context.storage:import(inventory.name, slotNo, item.count, item)
				end
			end

			if type(entry.slot) == 'number' then
				importSlot(entry.slot)
			else
				for i = 1, inventory.adapter.size() do
					importSlot(i)
				end
			end
		end
	end
end

Milo:registerTask(ImportTask)
