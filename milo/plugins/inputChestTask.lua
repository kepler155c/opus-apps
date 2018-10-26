local Milo = require('milo')

local device = _G.device

local InputChest = {
	name = 'input',
	priority = 10,
}

function InputChest:cycle(context)
	for source,v in pairs(context.config.remoteDefaults) do
		if v.mtype == 'input' then
			local inventory = device[source]

			local list = inventory and inventory.list and inventory.list()
			if list then
				for slot, item in pairs(list) do
					context.storage:import(source, slot, item.count, item)
				end
			end
		end
	end
end

Milo:registerTask(InputChest)
