local Craft  = require('milo.craft2')
local itemDB = require('core.itemDB')
local Milo   = require('milo')

local BLAZE_POWDER = "minecraft:blaze_powder"

local PotionImportTask = {
	name = 'potions',
	priority = 30,
	brewQueue = { },
}

function PotionImportTask:cycle(context)
	for bs in context.storage:filterActive('brewingStand') do
		if bs.adapter.getBrewTime() == 0 then
			local list = bs.adapter.list()

			-- refill blaze powder
			if not list[5] then
				local blazePowder = context.storage.cache[BLAZE_POWDER]
				if blazePowder then
					context.storage:export(bs, 5, 1, blazePowder)
				else
					local item = itemDB:get(BLAZE_POWDER) or itemDB:splitKey(BLAZE_POWDER)
					item.requested = 1
					Milo:requestCrafting(item)
				end
			end

			if list[1] and not list[4] then
				-- brewing has completd

				if self.brewQueue[bs.name] and list[1] then
					local key = itemDB:makeKey(list[1])
					if not Craft.findRecipe(key) then
						Milo:saveMachineRecipe(self.brewQueue[bs.name], list[1], bs.name)
					end
				end

				for slot = 1, 3 do
					if list[slot] then
						context.storage:import(bs, slot, 1, list[slot])
					end
				end
			end
			self.brewQueue[bs.name] = nil

		elseif not self.brewQueue[bs.name] then
			local recipe = {
				count       = 3,
				ingredients = { },
				maxCount    = 1,
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
					recipe.ingredients[i] = itemDB:makeKey(list[i])
				end

				self.brewQueue[bs.name] = recipe
			end
		end
	end
end

Milo:registerTask(PotionImportTask)
