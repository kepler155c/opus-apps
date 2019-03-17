local itemDB = require('core.itemDB')
local Milo   = require('milo')

local parallel = _G.parallel

local ImportTask = {
	name = 'importer',
	priority = 20,
}

local function filter(a)
	return a.imports
end

function ImportTask:cycle(context)
	local tasks = { }

	for node in context.storage:filterActive('machine', filter) do
		table.insert(tasks, function()
			local s, m = pcall(function()
				for _, entry in pairs(node.imports) do

					local function itemMatchesFilter(item)
						if not entry.ignoreDamage and not entry.ignoreNbtHash then
							local key = itemDB:makeKey(item)
							return entry.filter[key]
						end

						for key in pairs(entry.filter) do
							local v = itemDB:splitKey(key)
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
							if context.storage:import(node, slotNo, item.count, item) ~= item.count then
								_G._debug('IMPORTER warning: Failed to import %s(%d) %s[%d]',
									node.displayName or node.name, slotNo, item.name, item.count)
							end
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
		end)
	end

	if #tasks > 0 then
		parallel.waitForAll(table.unpack(tasks))
	end
end

Milo:registerTask(ImportTask)
