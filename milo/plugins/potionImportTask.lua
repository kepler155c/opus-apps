local Milo = require('milo')

local device = _G.device

local PotionImportTask = {
	priority = 3,
}

function PotionImportTask:cycle(context)
	for _, v in pairs(device) do
		if v.type == 'minecraft:brewing_stand' and v.getBrewTime() == 0 then
			local list = v.list()
			if not list[4] then
				for i = 1, 3 do
					if list[i] then
						context.inventoryAdapter:insert(i, 1, nil, list[i], v.name)
					end
				end
			end
		end
	end
end

Milo:registerTask(PotionImportTask)
