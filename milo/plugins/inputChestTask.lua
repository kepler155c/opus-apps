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
		local s, m = pcall(function()
			for slot, item in pairs(node.adapter.list()) do
				tasks:add(function()
					context.storage:import(node, slot, item.count, item)
				end)
			end
		end)
		if not s and m then
			_G._debug('INPUT error: ' .. m)
		end
	end

	tasks:run()
end

Milo:registerTask(InputChest)
