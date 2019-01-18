local Milo = require('milo')

local InputChest = {
	name = 'input',
	priority = 10,
}

function InputChest:cycle(context)
	for node in context.storage:filterActive('input') do
		for slot, item in pairs(node.adapter.list()) do
			local s, m = pcall(function()
				context.storage:import(node, slot, item.count, item)
			end)
			if not s and m then
				_G._debug('INPUT error: ' .. m)
			end
		end
	end
end

Milo:registerTask(InputChest)
