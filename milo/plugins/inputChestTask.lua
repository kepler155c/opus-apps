local Milo = require('milo')

local InputChest = {
	name = 'input',
	priority = 10,
}

function InputChest:cycle(context)
	for inventory in context.storage:filterActive('input') do
		for slot, item in pairs(inventory.adapter.list()) do
			context.storage:import(inventory.name, slot, item.count, item)
		end
	end
end

Milo:registerTask(InputChest)
