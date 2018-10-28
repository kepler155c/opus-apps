local Craft = require('turtle.craft')
local Milo  = require('milo')

local device = _G.device

local PotionImportTask = {
	name = 'potions',
	priority = 30,
	brewQueue = { },
}

function PotionImportTask:cycle(context)
	for _, v in pairs(device) do
		if v.type == 'minecraft:brewing_stand' then
			if v.getBrewTime() == 0 then
				local list = v.list()

				if list[1] and not list[4] then
					-- brewing has completd

					if self.brewQueue[v.name] and list[1] then
						local key = Milo:uniqueKey(list[1])
						if not Craft.findRecipe(key) then
debug('saving new recipe')
							Milo:saveMachineRecipe(self.brewQueue[v.name], list[1], v.name)
						end
					end
					for slot = 1, 3 do
						if list[slot] then
							context.storage:import(v.name, slot, 1, list[slot])
						end
					end
				end
				self.brewQueue[v.name] = nil

			elseif not self.brewQueue[v.name] then
				local recipe = {
					count       = 3,
					ingredients = { },
					maxCount    = 3,
				}
				local list = v.list()

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

					self.brewQueue[v.name] = recipe
				end
			end
		end
	end
end

Milo:registerTask(PotionImportTask)
