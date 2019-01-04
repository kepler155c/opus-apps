local itemDB = require('itemDB')
local Milo   = require('milo')

local ImportTask = {
	name = 'importer',
	priority = 20,
}

local function filter(a)
	return a.imports
end

function ImportTask:cycle(context)
	for node in context.storage:filterActive('machine', filter) do
		local s, m = pcall(function()
			for _, entry in pairs(node.imports) do

				local function itemMatchesFilter(item)
					if not entry.ignoreDamage and not entry.ignoreNbtHash then
						local key = Milo:uniqueKey(item)
						return entry.filter[key]
					end

					for key in pairs(entry.filter) do
						local v = Milo:splitKey(key)
						if item.name == v.name and
							(entry.ignoreDamage or item.damage == v.damage) and
							(entry.ignoreNbtHash or item.nbtHash == v.nbtHash) then
							return true
						end
					end
				end

				local function matchesFilter(item)
					if not entry.filter then
						return true
					end

					if entry.blacklist then
						return not itemMatchesFilter(item)
					end

					return itemMatchesFilter(item)
				end

				local list = node.adapter.list()

				local function importSlot(slotNo)
					local item = itemDB:get(list[slotNo], function()
						return node.adapter.getItemMeta(slotNo)
					end)
					if item and matchesFilter(item) then
						context.storage:import(node, slotNo, item.count, item)
					end
				end

				if type(entry.slot) == 'number' then
					if list[entry.slot] then
						importSlot(entry.slot)
					end
				else
					for i in pairs(list) do
						importSlot(i)
					end
				end
			end
		end)
		if not s and m then
			_G._debug('IMPORTER error: ' .. m)
		end
	end
end

Milo:registerTask(ImportTask)
