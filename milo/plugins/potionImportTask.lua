local Milo = require('milo')

local device = _G.device

local PotionImportTask = {
	name = 'potions',
	priority = 30,
}

function PotionImportTask:cycle(context)
	for _, v in pairs(device) do
		if v.type == 'minecraft:brewing_stand' and v.getBrewTime() == 0 then
			local list = v.list()
			if not list[4] then
				for slot = 1, 3 do
					if list[slot] then
						context.storage:import(v.name, slot, 1, list[slot])
					end
				end
			end
		end
	end
end

Milo:registerTask(PotionImportTask)
