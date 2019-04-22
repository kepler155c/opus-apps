local Milo  = require('milo')
local Tasks = require('milo.taskRunner')

local InputChest = {
	name = 'input',
	priority = 10,
}

function InputChest:cycle(context)
	local tasks = Tasks({
		errorMsg = 'INPUT error: '
	})

	for node in context.storage:filterActive('input') do
		tasks:add(function()
			for slot, item in pairs(node.adapter.list()) do
				if context.storage:import(node, slot, item.count, item) ~= item.count then
					break
				end
			end
		end)
	end

	tasks:run()
end

Milo:registerTask(InputChest)
