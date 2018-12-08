local Milo = require('milo')

local InputChest = {
	name = 'input',
	priority = 10,
}

function InputChest:cycle(context)
	for node in context.storage:filterActive('input') do
		for slot, item in pairs(node.adapter.list()) do
			context.storage:import(node, slot, item.count, item)
		end
	end
end

Milo:registerTask(InputChest)
