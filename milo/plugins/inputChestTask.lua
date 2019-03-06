local Milo = require('milo')

local parallel = _G.parallel

local InputChest = {
	name = 'input',
	priority = 10,
}

function InputChest:cycle(context)
	local tasks = { }
	for node in context.storage:filterActive('input') do
		table.insert(tasks, function()
			local s, m = pcall(function()
				for slot, item in pairs(node.adapter.list()) do
					local s, m = pcall(function()
						context.storage:import(node, slot, item.count, item)
					end)
					if not s and m then
						_G._debug('INPUT error: ' .. m)
					end
				end
			end)

			if not s and m then
				_G._debug('INPUT error: ' .. m)
			end
		end)
	end

	if #tasks > 0 then
		parallel.waitForAll(table.unpack(tasks))
	end
end

Milo:registerTask(InputChest)
