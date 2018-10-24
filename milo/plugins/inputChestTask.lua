local Milo = require('milo')

local device = _G.device

local InputChest = {
	priority = 1,
}

function InputChest:cycle(context)
	for name,v in pairs(context.config.remoteDefaults) do
		if v.mtype == 'input' then
			local inventory = device[name]

			local list = inventory and inventory.list and inventory.list()
			if list then
				for slotNo, slot in pairs(list) do
					context.inventoryAdapter:insert(slotNo, slot.count, nil, slot, name)
				end
			end
		end
	end
end

Milo:registerTask(InputChest)
