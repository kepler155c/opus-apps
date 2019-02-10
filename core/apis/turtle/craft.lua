local itemDB = require('core.itemDB')
local Util   = require('util')

local fs     = _G.fs
local turtle = _G.turtle

local RECIPES_DIR  = 'packages/core/etc/recipes'
local USER_RECIPES = 'usr/config/recipes.db'

local Craft = { }

local function clearGrid(inventoryAdapter)
	for i = 1, 16 do
		local count = turtle.getItemCount(i)
		if count > 0 then
			inventoryAdapter:insert(i, count)
			if turtle.getItemCount(i) ~= 0 then
				-- inventory is possibly full
				return false
			end
		end
	end
	return true
end

local function splitKey(key)
	local t = Util.split(key, '(.-):')
	local item = { }
	if #t[#t] > 8 then
		item.nbtHash = table.remove(t)
	end
	item.damage = tonumber(table.remove(t))
	item.name = table.concat(t, ':')
	return item
end

function Craft.getItemCount(items, item)
	if type(item) == 'string' then
		item = splitKey(item)
	end

	local count = 0
	for _,v in pairs(items) do
		if v.name == item.name and
			 (not item.damage or v.damage == item.damage) and
			 v.nbtHash == item.nbtHash then
			if item.damage then
				return v.count
			end
			count = count + v.count
		end
	end
	return count
end

local function turtleCraft(recipe, qty, inventoryAdapter)
	if not clearGrid(inventoryAdapter) then
		return false
	end

	for k,v in pairs(recipe.ingredients) do
		local item = splitKey(v)
		local provideQty = qty
		--[[
		Turtles can only craft 1 item at a time when using a tool.

		if recipe.craftingTools and recipe.craftingTools[k] then
			provideQty = 1
		end
		]]--
		inventoryAdapter:provide(item, provideQty, k)
		if turtle.getItemCount(k) == 0 then -- ~= qty then
																				-- FIX: ingredients cannot be stacked
--debug('failed ' .. v .. ' - ' .. provideQty)
			return false
		end
	end

	return turtle.craft()
end

function Craft.loadRecipes()
	Craft.recipes = { }

	Util.merge(Craft.recipes, (Util.readTable(fs.combine(RECIPES_DIR, 'minecraft.db')) or { }).recipes)

	local config = Util.readTable('usr/config/recipeBooks.db') or { }
	for _, book in pairs(config) do
		local recipeFile = Util.readTable(book)
		Util.merge(Craft.recipes, recipeFile.recipes)
	end

	local recipes = Util.readTable(USER_RECIPES) or { }
	Util.merge(Craft.recipes, recipes)
end

function Craft.sumIngredients(recipe)
	-- produces { ['minecraft:planks:0'] = 8 }
	local t = { }
	for _,item in pairs(recipe.ingredients) do
		t[item] = (t[item] or 0) + 1
	end
-- need a check for crafting tool
	return t
end

function Craft.craftRecipe(recipe, count, inventoryAdapter)
	if type(recipe) == 'string' then
		recipe = Craft.recipes[recipe]
		if not recipe then
			return 0, 'No recipe'
		end
	end

	local items = inventoryAdapter:listItems()
	if not items then
		return 0, 'Inventory changed'
	end

	count = math.ceil(count / recipe.count)
	local maxCount = recipe.maxCount or math.floor(64 / recipe.count)

	for key,icount in pairs(Craft.sumIngredients(recipe)) do
		local itemCount = Craft.getItemCount(items, key)
		local need = icount * count
		if recipe.craftingTools and recipe.craftingTools[key] then
			need = 1
		end
		maxCount = math.min(maxCount, itemDB:getMaxCount(key))
		if itemCount < need then
			local irecipe = Craft.findRecipe(key)
			if irecipe then
				local iqty = need - itemCount
				local crafted = Craft.craftRecipe(irecipe, iqty, inventoryAdapter)
				if crafted ~= iqty then
					turtle.select(1)
					return 0
				end
			end
		end
	end

	local crafted = 0
	repeat
		if not turtleCraft(recipe, math.min(count, maxCount), inventoryAdapter) then
			turtle.select(1)
			break
		end
		crafted = crafted + math.min(count, maxCount)
		count = count - maxCount
	until count <= 0

	clearGrid(inventoryAdapter)
	turtle.select(1)
	return crafted * recipe.count
end

local function makeRecipeKey(item)
	if type(item) == 'string' then
		item = splitKey(item)
	end
	return table.concat({ item.name, item.damage or 0, item.nbtHash }, ':')
end

function Craft.findRecipe(key)
	if type(key) ~= 'string' then
		key = itemDB:makeKey(key)
	end

	local item = itemDB:splitKey(key)
	if item.damage then
		return Craft.recipes[makeRecipeKey(item)]
	end

	-- handle cases where the request is like : IC2:reactorVent:*
	for rkey,recipe in pairs(Craft.recipes) do
		local r = itemDB:splitKey(rkey)
		if item.name == r.name and
			 (not item.nbtHash or r.nbtHash == item.nbtHash) then
			 return recipe
		end
	end
end

-- determine the full list of ingredients needed to craft
-- a quantity of a recipe.
function Craft.getResourceList(inRecipe, items, inCount)
	local summed = { }

	local function sumItems(recipe, key, count)
		local item = itemDB:splitKey(key)
		local summedItem = summed[key]
		if not summedItem then
			summedItem = Util.shallowCopy(item)
			summedItem.recipe = Craft.findRecipe(key)
			summedItem.count = Craft.getItemCount(items, item)
			summedItem.displayName = itemDB:getName(item)
			summedItem.total = 0
			summedItem.need = 0
			summedItem.used = 0
			summed[key] = summedItem
		end
		local total = count
		local used = math.min(summedItem.count, total)
		local need = total - used

		if recipe.craftingTools and recipe.craftingTools[key] then
			summedItem.total = 1
			if summedItem.count > 0 then
				summedItem.used = 1
				summedItem.need = 0
				need = 0
			elseif not summedItem.recipe then
				summedItem.need = 1
				need = 1
			else
				need = 1
			end
		else
			summedItem.total = summedItem.total + total
			summedItem.count = summedItem.count - used
			summedItem.used = summedItem.used + used
			if not summedItem.recipe then
				summedItem.need = summedItem.need + need
			end
		end

		if need > 0 and summedItem.recipe then
			need = math.ceil(need / summedItem.recipe.count)
			for ikey,iqty in pairs(Craft.sumIngredients(summedItem.recipe)) do
				sumItems(summedItem.recipe, ikey, math.ceil(need * iqty))
			end
		end
	end

	inCount = math.ceil(inCount / inRecipe.count)
	for ikey,iqty in pairs(Craft.sumIngredients(inRecipe)) do
		sumItems(inRecipe, ikey, math.ceil(inCount * iqty))
	end

	return summed
end

function Craft.getResourceList4(inRecipe, items, count)
	local summed = Craft.getResourceList(inRecipe, items, count)
-- filter down to just raw materials
	return Util.filter(summed, function(a) return a.used > 0 or a.need > 0 end)
end

-- given a certain quantity, return how many of those can be crafted
function Craft.getCraftableAmount(inRecipe, count, items, missing)
	local function sumItems(recipe, summedItems, count)
		local canCraft = 0

		for _ = 1, count do
			for _,item in pairs(recipe.ingredients) do
				local summedItem = summedItems[item] or Craft.getItemCount(items, item)

				local irecipe = Craft.findRecipe(item)
				if irecipe and summedItem <= 0 then
					summedItem = summedItem + sumItems(irecipe, summedItems, 1)
				end
				if summedItem <= 0 then
					if missing and not irecipe then
						missing.name = item
					end
					return canCraft
				end
				if not recipe.craftingTools or not recipe.craftingTools[item] then
					summedItems[item] = summedItem - 1
				end
			end
			canCraft = canCraft + recipe.count
		end

		return canCraft
	end

	return sumItems(inRecipe, { }, math.ceil(count / inRecipe.count))
end

function Craft.canCraft(item, count, items)
	return Craft.getCraftableAmount(Craft.recipes[item], count, items) == count
end

function Craft.setRecipes(recipes)
	Craft.recipes = recipes
end

function Craft.getCraftableAmountTest()
	local results = { }
	Craft.setRecipes(Util.readTable('usr/etc/recipes.db'))

	local items = {
		{ name = 'minecraft:planks', damage = 0, count = 5 },
		{ name = 'minecraft:log',    damage = 0, count = 2 },
	}
	results[1] = { item = 'chest', expected = 1,
		got = Craft.getCraftableAmount(Craft.recipes['minecraft:chest:0'], 2, items) }

	items = {
		{ name = 'minecraft:log',    damage = 0, count = 1 },
		{ name = 'minecraft:coal',   damage = 1, count = 1 },
	}
	results[2] = { item = 'torch', expected = 4,
		got = Craft.getCraftableAmount(Craft.recipes['minecraft:torch:0'], 4, items) }

	return results
end

function Craft.craftRecipeTest(name, count)
	local ChestAdapter = require('core.chestAdapter18')
	local chestAdapter = ChestAdapter({ wrapSide = 'top', direction = 'down' })
	Craft.setRecipes(Util.readTable('usr/etc/recipes.db'))
	return { Craft.craftRecipe(Craft.recipes[name], count, chestAdapter) }
end

Craft.loadRecipes()

return Craft
