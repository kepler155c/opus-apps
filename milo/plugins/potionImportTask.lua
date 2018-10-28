local Craft = require('turtle.craft')
local Milo  = require('milo')

local PotionImportTask = {
	name = 'potions',
	priority = 30,
	brewQueue = { },
}

local function filter(a)
	return a.adapter.type == 'minecraft:brewing_stand'
end

function PotionImportTask:cycle(context)
	for bs in context.storage:filterActive('machine', filter) do
		if bs.adapter.getBrewTime() == 0 then
			local list = bs.adapter.list()

			if list[1] and not list[4] then
				-- brewing has completd

				if self.brewQueue[bs.name] and list[1] then
					local key = Milo:uniqueKey(list[1])
					if not Craft.findRecipe(key) then
						Milo:saveMachineRecipe(self.brewQueue[bs.name], list[1], bs.name)
					end
				end
				for slot = 1, 3 do
					if list[slot] then
						context.storage:import(bs.name, slot, 1, list[slot])
					end
				end
			end
			self.brewQueue[bs.name] = nil

		elseif not self.brewQueue[bs.name] then
			local recipe = {
				count       = 3,
				ingredients = { },
				maxCount    = 3,
			}
			local list = bs.adapter.list()

			local function valid()
				for i = 1, 4 do
					if not list[i] then
						return false
					end
				end
				return true
			end

			if valid() then
				for i = 1, 4 do
					recipe.ingredients[i] = Milo:uniqueKey(list[i])
				end

				self.brewQueue[bs.name] = recipe
			end
		end
	end
end

Milo:registerTask(PotionImportTask)
