local itemDB = require('itemDB')
local Util   = require('util')

local device = _G.device
local fs     = _G.fs
local turtle = _G.turtle

local Craft = {
	STATUS_INFO    = 'info',
	STATUS_WARNING = 'warning',
	STATUS_ERROR   = 'error',
	STATUS_SUCCESS = 'success',

	RECIPES_DIR    = 'usr/etc/recipes',
	USER_RECIPES   = 'usr/config/recipes.db',
	MACHINE_LOOKUP = 'usr/config/machine_crafting.db',
}

local function clearGrid(inventoryAdapter)
	turtle.eachFilledSlot(function(slot)
		inventoryAdapter:insert(slot.index, slot.count, nil, slot)
	end)

	for i = 1, 16 do
		if turtle.getItemCount(i) ~= 0 then
			return false
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

local function makeRecipeKey(item)
	if type(item) == 'string' then
		item = splitKey(item)
	end
	return table.concat({ item.name, item.damage or 0, item.nbtHash }, ':')
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

function Craft.sumIngredients(recipe)
	-- produces { ['minecraft:planks:0'] = 8 }
	local t = { }
	for _,item in pairs(recipe.ingredients) do
		t[item] = (t[item] or 0) + 1
	end
-- need a check for crafting tool
	return t
end

local function machineCraft(recipe, inventoryAdapter, machineName, request, count)
	if request.pending then
		local imported = (inventoryAdapter.activity[recipe.result] or 0)
		request.pending = request.pending - imported
		request.crafted = request.crafted + imported
		if request.pending <= 0 then
			request.pending = nil
			request.statusCode = nil
			request.status = nil
		end
		return
	end

	local machine = device[machineName]
	if not machine then
		request.status = 'machine not found'
		request.statusCode = Craft.STATUS_ERROR
		return
	end

	for k in pairs(recipe.ingredients) do
		if machine.getItemMeta(k) then
			request.status = 'machine in use'
			request.statusCode = Craft.STATUS_WARNING
			return
		end
	end

	local xferred = { }
	for k,v in pairs(recipe.ingredients) do
		local provided = inventoryAdapter:provide(splitKey(v), count, k, machineName)
		xferred[k] = {
			key = v,
			count = provided,
		}
		if provided ~= count then
			-- take back out whatever we put in
			for k2,v2 in pairs(xferred) do
				if v2.count > 0 then
					inventoryAdapter:import(machineName, k2, v2.count, splitKey(v2.key))
				end
			end
			request.status = 'Invalid recipe'
			request.statusCode = Craft.STATUS_ERROR
			return
		end
	end
	request.status = 'processing'
	request.statusCode = Craft.STATUS_INFO
	request.pending = count * recipe.count
end

local function turtleCraft(recipe, inventoryAdapter, request, count)
	if not clearGrid(inventoryAdapter) then
		request.status = 'grid in use'
		request.statusCode = Craft.STATUS_ERROR
		return
	end

	for k,v in pairs(recipe.ingredients) do
		local item = splitKey(v)
		if inventoryAdapter:provide(item, count, k) ~= count then
																				-- FIX: ingredients cannot be stacked
			request.status = 'unknown error'
			request.statusCode = Craft.STATUS_ERROR
			return
		end
	end

	turtle.select(1)
	if turtle.craft() then
		request.crafted = request.crafted + count * recipe.count
		return true
	end
	request.status = 'Failed to craft'
	request.statusCode = Craft.STATUS_ERROR
end

function Craft.craftRecipe(recipe, count, inventoryAdapter, origItem)
	if type(recipe) == 'string' then
		recipe = Craft.recipes[recipe]
		if not recipe then
			return 0, 'No recipe'
		end
	end

	-- wait til all requests have been completed
	local isPending = false
	for key, request in pairs(origItem.ingredients) do
		if request.pending then
			local irecipe = Craft.findRecipe(key)
			machineCraft(irecipe, inventoryAdapter,
				Craft.machineLookup[irecipe.result], request)
			isPending = request.pending or isPending
		end
	end

	local crafted = 0
	--if not isPending then
		for _,key in pairs(Util.keys(origItem.ingredients)) do
			local e = origItem.ingredients[key]
			if e and e.transient then
				origItem.ingredients[key] = nil
			end
		end
		crafted = Craft.craftRecipeInternal(recipe, count, inventoryAdapter, origItem)
	--end

	for _, request in pairs(origItem.ingredients) do
		if request.crafted >= request.count then
if request.pending then
	_debug('??')
	_debug(request)
end
			request.status = nil
			request.statusCode = Craft.STATUS_SUCCESS
		end
	end

	return crafted
end

function Craft.craftRecipeInternal(recipe, count, inventoryAdapter, origItem)
	local items = inventoryAdapter:listItems()
	if not items then
		return 0, 'Inventory changed'
	end

	local request = origItem.ingredients[recipe.result]
	if not request then
		request = {
			crafted = 0,
			count = count,
		}
		origItem.ingredients[recipe.result] = request
	end

	if request.pending then
		--machineCraft(recipe, inventoryAdapter,
		--		Craft.machineLookup[recipe.result], request)
		return 0
	end

	local canCraft = Craft.getCraftableAmount(recipe, count, items, { })
	if canCraft == 0 then

		local resourceList = Craft.getResourceList(recipe, items, count)
_G._p2 = resourceList
		for k,v in pairs(resourceList) do
			if v.need > 0 then
				if not origItem.ingredients[k] then
					origItem.ingredients[k] = {
						status = 'No recipe',
						statusCode = Craft.STATUS_ERROR,
						count = v.need,
						crafted = 0,
						transient = true,
					}
				end
			end
		end
		return 0
	end

	count = math.ceil(canCraft / recipe.count)
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
			if not irecipe then
				return 0
			end
			local iqty = need - itemCount
			local crafted = Craft.craftRecipeInternal(irecipe, iqty, inventoryAdapter, origItem)
			if crafted ~= iqty then
				return 0
			end
		end
	end

	local crafted = 0
	repeat
		local batch = math.min(count, maxCount)
		if Craft.machineLookup[recipe.result] then
			if not machineCraft(recipe, inventoryAdapter,
				Craft.machineLookup[recipe.result], request, batch) then
				break
			end
		elseif not turtleCraft(recipe, inventoryAdapter, request, batch) then
			break
		end

		crafted = crafted + batch
		count = count - maxCount
	until count <= 0

	return crafted * recipe.count
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

function Craft.loadRecipes()
	Craft.recipes = { }

	Util.merge(Craft.recipes, (Util.readTable(fs.combine(Craft.RECIPES_DIR, 'minecraft.db')) or { }).recipes)

	local config = Util.readTable('usr/config/recipeBooks.db') or { }
	for _, book in pairs(config) do
		local recipeFile = Util.readTable(book)
		Util.merge(Craft.recipes, recipeFile.recipes)
	end

	local recipes = Util.readTable(Craft.USER_RECIPES) or { }
	Util.merge(Craft.recipes, recipes)

	for k,v in pairs(Craft.recipes) do
		v.result = k
	end

	Craft.machineLookup = Util.readTable(Craft.MACHINE_LOOKUP) or { }
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
	local ChestAdapter = require('chestAdapter18')
	local chestAdapter = ChestAdapter({ wrapSide = 'top', direction = 'down' })
	Craft.setRecipes(Util.readTable('usr/etc/recipes.db'))
	return { Craft.craftRecipe(Craft.recipes[name], count, chestAdapter) }
end

Craft.loadRecipes()

return Craft
