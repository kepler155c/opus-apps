local itemDB = require('core.itemDB')
local Milo   = require('milo')
local Tasks  = require('milo.taskRunner')

local ImportTask = {
	name = 'importer',
	priority = 20,
}

local function filter(a)
	return a.imports
end

function ImportTask:cycle(context)
	local tasks = Tasks({
		errorMsg = 'IMPORT error: '
	})

	for node in context.storage:filterActive('machine', filter) do
		tasks:add(function()
			for _, entry in pairs(node.imports) do

				local function itemMatchesFilter(item)
					if not entry.ignoreNbt then
						local key = itemDB:makeKey(item)
						return entry.filter[key]
					end

					for key in pairs(entry.filter) do
						local v = itemDB:splitKey(key)
						if item.name == v.name and
							(entry.ignoreNbt or item.nbt == v.nbt) then
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
						return node.adapter.getItemDetail(slotNo)
					end)
					if item and matchesFilter(item) then
						if context.storage:import(node, slotNo, item.count, item) ~= item.count then
							error('Failed to import %s', item.name)
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
	end

	function tasks:onError(msg)
		_G._syslog('IMPORT error: ' .. msg)
	end
	tasks:run()
end

Milo:registerTask(ImportTask)
