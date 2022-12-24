local Craft  = require('milo.craft2')
local itemDB = require('core.itemDB')
local Milo   = require('milo')
local UI     = require('opus.ui')

local recipeTab = UI.Tab {
	title = 'Recipe',
	index = 2,
	grid = UI.ScrollingGrid {
		x = 2, ex = -2, y = 2, ey = -4,
		disableHeader = true,
		columns = {
			{ heading = 'Slot', key = 'slot', width = 2 },
			{ heading = 'Count', key = 'count', width = 2 },
			{ heading = 'Key', key = 'key' },
		},
		sortColumn = 'slot',
	},
	ignoreResultNBT = UI.Button {
		x = 2, y = -2,
		text = 'Ignore Result NBT', event = 'ignore_result_nbt',
	},
	ignoreNBT = UI.Button {
		x = -13, y = -2,
		text = 'Ignore NBT', event = 'ignore_nbt',
	},
}

function recipeTab:setItem(item)
	self.item = item
	self.recipe = Craft.findRecipe(self.item)

	self.parent:setActive(self, self.recipe)

	local t = { }
	if self.recipe then
		for k, v in Craft.ingredients(self.recipe) do
			table.insert(t, {
				slot = k,
				key = v.key,
				count = v.count,
			})
		end
		local key = itemDB:splitKey(self.recipe.result)
		self.ignoreResultNBT.inactive = not key.nbt
	end
	self.grid:setValues(t)
end

function recipeTab:eventHandler(event)
	if event.type == 'ignore_result_nbt' then
		-- remove old entry
		Milo:updateRecipe(self.recipe.result)

		local item = itemDB:splitKey(self.recipe.result)
		item.nbt = nil
		self.recipe.result = itemDB:makeKey(item)

		-- add updated entry
		Milo:updateRecipe(self.recipe.result, self.recipe)

		self.ignoreResultNBT.inactive = true
		self:emit({ type = 'info_message', message = 'Recipe updated' })

	elseif event.type == 'grid_focus_row' then
		local key = itemDB:splitKey(event.selected.key)
		self.ignoreNBT.inactive = not key.nbt
		self.ignoreNBT:draw()

	elseif event.type == 'ignore_nbt' then
		local selected = self.grid:getSelected()
		local item = itemDB:splitKey(selected.key)
		item.nbt = nil
		selected.key = itemDB:makeKey(item)
		self.grid:draw()

		self.recipe.ingredients = { }
		for _, v in pairs(self.grid.values) do
			self.recipe.ingredients[v.slot] = v.key
		end

		Milo:updateRecipe(self.recipe.result, self.recipe)
		self:emit({ type = 'info_message', message = 'Recipe updated' })

		return true
	end
end

return { itemTab = recipeTab }
