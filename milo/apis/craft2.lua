local itemDB = require('core.itemDB')
local Tasks  = require('milo.taskRunner')
local Util   = require('opus.util')

local fs       = _G.fs
local turtle   = _G.turtle

local Craft = {
	STATUS_INFO    = 'info',
	STATUS_WARNING = 'warning',
	STATUS_ERROR   = 'error',
	STATUS_SUCCESS = 'success',

	RECIPES_DIR    = 'packages/recipeBook/etc/recipes',
	USER_DIR       = 'usr/etc/recipes',
	USER_RECIPES   = 'usr/config/recipes.db',
	MACHINE_LOOKUP = 'usr/config/machine_crafting.db',
}

local function splitKey(key)
	local t = Util.split(key, '(.-):')
	local item = { }

	if t[3] then
		item.nbt = t[3]
		t[3] = nil
	end

	item.name = table.concat(t, ':')
	return item
end

local function makeRecipeKey(item)
	if type(item) == 'string' then
		item = splitKey(item)
	end
	return table.concat({ item.name, item.nbt }, ':')
end

local function convert(ingredient)
	return type(ingredient) == 'table' and ingredient or {
		key = ingredient,
		count = 1,
	}
end

local function getCraftingTool(storage, item)
	local items = storage:listItems()

	for _,v in pairs(items) do
		if item.name == v.name and
			(not item.nbt or item.nbt == v.nbt) then
			return v
		end
	end

	return item
end

function Craft.ingredients(recipe)
	local i = 0
	local keys = Util.keys(recipe.ingredients)
	return function()
		i = i + 1
		local a = keys[i]
		if a then
			return a, convert(recipe.ingredients[a])
		end
	end
end

function Craft.clearGrid(storage)
	local success = true
	local tasks = Tasks()

	for index, slot in pairs(storage.turtleInventory.adapter.list()) do
		tasks:add(function()
			if storage:import(storage.turtleInventory, index, slot.count, slot) ~= slot.count then
				success = false
			end
		end)
	end

	tasks:run()

	return success
end

function Craft.getItemCount(items, item)
	if type(item) == 'string' then
		item = splitKey(item)
	end

	local count = 0
	for _,v in pairs(items) do
		if v.name == item.name and
			 v.nbt == item.nbt then
			count = count + v.count
		end
	end
	return count
end

function Craft.sumIngredients(recipe)
	-- produces { ['minecraft:planks:0'] = 8 }
	local t = { }
	for _,entry in pairs(recipe.ingredients) do
		local item = convert(entry)
		t[item.key] = (t[item.key] or 0) + item.count
	end
	return t
end

local function machineCraft(recipe, storage, machineName, request, count, item)
	local machine = storage.nodes[machineName]
	if not machine then
		request.status = 'machine not found'
		request.statusCode = Craft.STATUS_ERROR
		return
	end

	if not machine.adapter or not machine.adapter.online then
		request.status = 'machine offline'
		request.statusCode = Craft.STATUS_ERROR
		return
	end

	local pending = item.pending[recipe.result] or 0

	local list = machine.adapter.list()
	for k in pairs(recipe.ingredients) do
		if list[k] then
			if pending >  0 then
				request.status = 'processing'
				request.statusCode = Craft.STATUS_INFO
			else
				request.status = 'machine in use'
				request.statusCode = Craft.STATUS_WARNING
			end
			return
		end
	end

	if count > 0 then
		local xferred = { }
		for k,v in pairs(recipe.ingredients) do
			local entry = convert(v)
			local provided = storage:export(machine, k, count * entry.count, splitKey(entry.key))
			xferred[k] = {
				key = entry.key,
				count = provided,
			}
			if provided ~= count * entry.count then
				-- take back out whatever we put in
				for k2,v2 in pairs(xferred) do
					if v2.count > 0 then
						storage:import(machine, k2, v2.count, splitKey(v2.key))
					end
				end
				request.status = 'Invalid recipe'
				request.statusCode = Craft.STATUS_ERROR
				return
			end
		end
	end
	request.status = 'processing'
	request.statusCode = Craft.STATUS_INFO
	item.pending[recipe.result] = pending + (count * recipe.count)
end

local function turtleCraft(recipe, storage, request, count)
	if not Craft.clearGrid(storage) then
		request.status = 'grid in use'
		request.statusCode = Craft.STATUS_ERROR
		return
	end

	local failed
	local tasks = Tasks()

	for k,v in pairs(recipe.ingredients) do
		local item = splitKey(v)
		if recipe.craftingTools and recipe.craftingTools[v] then
			item = getCraftingTool(storage, item)
		end
		tasks:add(function()
			if storage:export(storage.turtleInventory, k, count, item) ~= count then
				request.status = 'rescan needed ?'
				request.statusCode = Craft.STATUS_ERROR
				failed = true
	_G._syslog('failed to export: ' .. item.name)
--	_G._p4 = recipe
--	_G._p = storage
--	_G._p2 = request
--read()
			end
		end)
	end

	tasks:run()

	if failed then
		Craft.clearGrid(storage)
		return
	end

	turtle.select(1)
	if turtle.craft() then
		local l = storage.turtleInventory.adapter.list()
		local crafted = l[1]
		if recipe.result ~= itemDB:makeKey(crafted) then
			_G._syslog('expected: ' .. recipe.result)
			_G._syslog('got: ' .. itemDB:makeKey(crafted))
			request.aborted = true
			request.status = 'Failed to craft: ' .. recipe.result
			request.statusCode = Craft.STATUS_ERROR
		else
			request.crafted = request.crafted + count * recipe.count
			--request.status = 'crafted'
			--request.statusCode = Craft.STATUS_SUCCESS
		end
	else
		_G._syslog('just failed')
		request.status = 'Failed to craft'
		request.statusCode = Craft.STATUS_ERROR
	end
	Craft.clearGrid(storage)
	return request.statusCode == Craft.STATUS_SUCCESS
end

function Craft.processPending(item, storage)
	for _, key in pairs(Util.keys(item.pending)) do
		local count = item.pending[key]
		local imported = storage.activity[key]
		if imported then
			local amount = math.min(imported, count)
			storage.activity[key] = imported - amount
			item.pending[key] = count - amount
			item.ingredients[key].crafted = item.ingredients[key].crafted + amount
			if item.pending[key] <= 0 then
				item.pending[key] = nil
			end
		end
	end
end

-- return a recipe if the ingredients will not produce recursion
local function findValidRecipe(key, path)
	local recipe = Craft.findRecipe(key)

	if recipe then
		for k in pairs(Craft.sumIngredients(recipe)) do
			if path[k] then
				return
			end
		end
		return recipe
	end
end

function Craft.craftRecipe(recipe, count, storage, origItem)
	if type(recipe) == 'string' then
		recipe = Craft.recipes[recipe]
		if not recipe then
			return 0, 'No recipe'
		end
	end

	local path = { [ recipe.result ] = true }
	return Craft.craftRecipeInternal(recipe, count, storage, origItem, path)
end

local function adjustCounts(recipe, count, ingredients, storage)
	-- decrement ingredients used
	for key,icount in pairs(Craft.sumIngredients(recipe)) do
		ingredients[key].count = ingredients[key].count - (icount * count)
	end

	-- increment crafted
	local result = ingredients[recipe.result]
	result.count = result.count + (count * recipe.count)
end

function Craft.craftRecipeInternal(recipe, count, storage, origItem, path)
	local request = origItem.ingredients[recipe.result]
	--[[
	if origItem.pending[recipe.result] then
		request.status = 'processing'
		request.statusCode = Craft.STATUS_INFO
		return 0
	end
	--]]
	count = count - (origItem.pending[recipe.result] or 0)
	local canCraft = Craft.getCraftableAmount(recipe, count, origItem.ingredients)
	if not origItem.forceCrafting and canCraft == 0 then
		return 0
	end

	canCraft = math.ceil(canCraft / recipe.count)
	if origItem.forceCrafting then
		count = math.ceil(count / recipe.count)
	else
		count = canCraft
	end

	local function maxBatch()
		local max = 64
		for _, i in Craft.ingredients(recipe) do
			max = math.min(max, math.floor(itemDB:getMaxCount(i.key) / i.count))
		end
		return max
	end

	local maxCount = recipe.maxCount or math.floor(64 / recipe.count)
	maxCount = math.min(maxCount, maxBatch())

	repeat
		local craftedIngredient
		local abort

		for key,icount in pairs(Craft.sumIngredients(recipe)) do
			local itemCount = Craft.getItemCount(origItem.ingredients, key)
			local need = icount * count
			if recipe.craftingTools and recipe.craftingTools[key] then
				need = 1
			end
			maxCount = math.min(maxCount, itemDB:getMaxCount(key))
			if itemCount < need then
				local irecipe = findValidRecipe(key, path)
				if not irecipe then
					abort = true
				else
					local iqty = need - itemCount
					local p = Util.shallowCopy(path)
					p[irecipe.result] = true
					local crafted = Craft.craftRecipeInternal(irecipe, iqty, storage, origItem, p)
					if not origItem.forceCrafting and crafted < iqty then
						abort = true
					end
					if origItem.forceCrafting and crafted < iqty then
						canCraft = math.min(canCraft, math.floor((itemCount + crafted) / icount))
					end
					if crafted > 0 then
						craftedIngredient = true
					end
				end
			end
		end
		if abort then
			return 0
		end
	until not craftedIngredient

	local crafted = 0
	while canCraft > 0 do
		local batch = math.min(canCraft, maxCount)
		local machine = Craft.machineLookup[recipe.result]

		if machine then
			if not machineCraft(recipe, storage, machine, request, batch, origItem) then
				break
			end
		elseif not turtleCraft(recipe, storage, request, batch) then
			break
		end

		adjustCounts(recipe, batch, origItem.ingredients, storage)

		crafted = crafted + batch
		canCraft = canCraft - maxCount
	end

	if request.aborted then
		origItem.aborted = true
		return 0
	end

	return crafted * recipe.count
end

function Craft.findRecipe(key)
	if type(key) ~= 'string' then
		key = itemDB:makeKey(key)
	end

	local item = itemDB:splitKey(key)
	return Craft.recipes[makeRecipeKey(item)]
end

-- determine the full list of ingredients needed to craft
-- a quantity of a recipe.
function Craft.getResourceList(inRecipe, items, inCount, pending)
	local summed = { }

	local function sumItems(recipe, key, count, path)
		local item = itemDB:splitKey(key)
		local summedItem = summed[key]
		if not summedItem then
			summedItem = Util.shallowCopy(item)
			summedItem.count = Craft.getItemCount(items, item)
			summedItem.displayName = itemDB:getName(item)
			summedItem.total = 0
			summedItem.need = 0
			summedItem.used = 0
			summed[key] = summedItem

			summedItem.recipe = findValidRecipe(key, path)
		end
		local total = count
		local used = math.min(summedItem.count, total)
		local need = total - used

		if pending and pending[key] then
			need = need - pending[key]
		end

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
			local p = Util.shallowCopy(path)
			p[summedItem.recipe.result] = true
			for ikey,iqty in pairs(Craft.sumIngredients(summedItem.recipe)) do
				sumItems(summedItem.recipe, ikey, math.ceil(need * iqty), p)
			end
		end
	end

	inCount = math.ceil(inCount / inRecipe.count)
	if pending and pending[inRecipe.result] then
		inCount = inCount - pending[inRecipe.result]
	end
	if inCount > 0 then
		local path = { [ inRecipe.result ] = true }
		for ikey,iqty in pairs(Craft.sumIngredients(inRecipe)) do
			sumItems(inRecipe, ikey, math.ceil(inCount * iqty), path)
		end
	end

	return summed
end

function Craft.getResourceList4(inRecipe, items, count)
	local summed = Craft.getResourceList(inRecipe, items, count)
	-- filter down to just raw materials
	return Util.filter(summed, function(a) return a.used > 0 or a.need > 0 end)
end

-- given a certain quantity, return how many of those can be crafted
function Craft.getCraftableAmount(inRecipe, inCount, items, missing)
	local function sumItems(recipe, summedItems, count, path)
		local canCraft = 0

		for _ = 1, count do
			for _,entry in pairs(recipe.ingredients) do
				local item = convert(entry)
				local summedItem = summedItems[item.key] or Craft.getItemCount(items, item.key)

				local irecipe = findValidRecipe(item.key, path)
				if irecipe and summedItem <= 0 then
					local p = Util.shallowCopy(path)
					p[irecipe.result] = true
					summedItem = summedItem + sumItems(irecipe, summedItems, item.count, p)
				end
				if summedItem <= 0 then
					if missing and not irecipe then
						missing.name = item.key
					end
					return canCraft
				end
				if not recipe.craftingTools or not recipe.craftingTools[item.key] then
					summedItems[item.key] = summedItem - item.count
				end
			end
			canCraft = canCraft + recipe.count
		end

		return canCraft
	end

	local path = { [ inRecipe.result ] = true }
	return sumItems(inRecipe, { }, math.ceil(inCount / inRecipe.count), path)
end

-- doesnt work :( solar panel 3 fails (qty 2)
function Craft.getCraftableAmountXXX(inRecipe, limit, items)
	local allIngredients = { }

	local function sumItems(recipe, count, path)
		local canCraft = 0

		for _ = 1, count do
			for iKey, iCount in pairs(Craft.sumIngredients(recipe)) do
				local quantity = allIngredients[iKey] or Craft.getItemCount(items, iKey)
				if quantity < iCount then
					local irecipe = findValidRecipe(iKey, path)
					if irecipe then
						local p = Util.shallowCopy(path)
						p[irecipe.result] = true
						quantity = quantity + sumItems(irecipe, iCount - quantity, p)
					end
				end
				if quantity < iCount then
					return canCraft
				end
				if not recipe.craftingTools or not recipe.craftingTools[iKey] then
					allIngredients[iKey] = quantity - iCount
				end
			end
			canCraft = canCraft + recipe.count
		end

		return canCraft
	end

	local path = { [ inRecipe.result ] = true }
	return sumItems(inRecipe, math.ceil(limit / inRecipe.count), path)
end

function Craft.loadRecipes()
	Craft.recipes = { }

	Util.merge(Craft.recipes, (Util.readTable(fs.combine(Craft.RECIPES_DIR, 'minecraft.db')) or { }).recipes)

	if fs.exists(Craft.USER_DIR) then
		for _, file in pairs(fs.list(Craft.USER_DIR)) do
			local recipeFile = Util.readTable(fs.combine(Craft.USER_DIR, file))
			Util.merge(Craft.recipes, recipeFile.recipes)
		end
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

Craft.loadRecipes()

return Craft
