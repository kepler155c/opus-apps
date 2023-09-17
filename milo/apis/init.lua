local Config = require('opus.config')
local Craft  = require('milo.craft2')
local itemDB = require('core.itemDB')
local Sound  = require('opus.sound')
local Util   = require('opus.util')

local os     = _G.os
local turtle = _G.turtle

local Milo = {
	RESOURCE_FILE = 'usr/config/resources.db',
}

function Milo:init(context)
	self.context = context
	context.userRecipes = Util.readTable(Craft.USER_RECIPES) or { }
end

function Milo:getContext()
	return self.context
end

function Milo:registerPlugin(plugin)
	for pluginType, value in pairs(plugin) do
		if not self.context.plugins[pluginType] then
			self.context.plugins[pluginType] = { value }
		else
			table.insert(self.context.plugins[pluginType], value)
		end
	end
end

function Milo:pauseCrafting(reason)
	local _, key = Util.find(self.context.state, 'key', reason.key)
	if not key then
		table.insert(self.context.state, reason)
		os.queueEvent('milo_pause', reason)
	end
end

function Milo:resumeCrafting(reason)
	local _, key = Util.find(self.context.state, 'key', reason.key)
	if key then
		table.remove(self.context.state, key)
		local n = self.context.state[#self.context.state]
		if n then
			os.queueEvent('milo_pause', n)
		else
			os.queueEvent('milo_resume')
		end
	end
end

function Milo:isCraftingPaused()
	return self.context.state[#self.context.state]
end

function Milo:getState(key)
	if not self.state then
		self.state = Config.load('milo.state')
	end
	return self.state[key]
end

function Milo:setState(key, value)
	if not self.state then
		self.state = Config.load('milo.state')
	end
	self.state[key] = value
	Config.update('milo.state', self.state)
end

function Milo:resetCraftingStatus()
	for _,key in pairs(Util.keys(self.context.craftingQueue)) do
		local item = self.context.craftingQueue[key]
		if item.crafted >= item.requested or item.aborted then
			self.context.craftingQueue[key] = nil
		end
	end
end

function Milo:registerTask(task)
	table.insert(self.context.tasks, task)
end

function Milo:getItem(inItem)
	return self:listItems()[inItem.key or itemDB:makeKey(inItem)]
end

-- returns a list of items that matches along with a total count
function Milo:getMatches(item, flags)
	local t = { }
	local count = 0
	local items = self:listItems()

	if not flags.ignoreNbt then
		local key = item.key or itemDB:makeKey(item)
		local v = items[key]
		if v then
			t[key] = Util.shallowCopy(v)
			count = v.count
		end

	else
		for key,v in pairs(items) do
			if item.name == v.name and
				(flags.ignoreNbt or item.nbt == v.nbt) then

				t[key] = Util.shallowCopy(v)
				count = count + v.count
			end
		end
	end

	return t, count
end

function Milo:clearGrid()
	return Craft.clearGrid(self.context.storage)
end

function Milo:getTurtleInventory()
	local list = { }

	for i, v in pairs(self.context.turtleInventory.adapter.list()) do
		list[i] = itemDB:get(v, function()
			return self.context.turtleInventory.adapter.getItemDetail(i)
		end)
	end

	itemDB:flush()
	return list
end

function Milo:requestCrafting(item)
	local key = itemDB:makeKey(item)

	if not self.context.craftingQueue[key] then
		item.crafted = 0
		item.pending = { }
		item.key = key
		self.context.craftingQueue[key] = item
		os.queueEvent('milo_cycle')
	end
end

-- queue an action that interacts with storage
function Milo:queueRequest(request, callback)
	os.queueEvent('milo_queue')
	table.insert(self.context.queue, {
		request = request,
		callback = callback
	})
end

function Milo:craftAndEject(item, count)
	local request = self:makeRequest(item, count, function(request)
		-- eject rest when finished crafted
		return self:eject(item, request.requested)
	end)

	return request
end

function Milo:makeRequest(item, count, callback)
	local current = self:getItem(item) or { count = 0 }

	if count <= 0 then
		return {
			requested = 0,
			craft = 0,
			count = 0,
			current = current.count,
			item = item,
			key = item.key or itemDB:makeKey(item),
		}
	end

	local toCraft = count - math.min(current.count, count)
	if toCraft > 0 then
		local recipe = Craft.findRecipe(itemDB:makeKey(item))
		if not recipe then
			toCraft = 0
		else
			-- if you ask for 1 stick, getCraftableAmount will return 4 (obviously)
			toCraft = math.min(toCraft, Craft.getCraftableAmount(recipe, toCraft, self:listItems(), { }))
		end
	end

	local request = {
		requested = count,
		craft = toCraft,
		count = math.min(count, current.count),
		current = current.count,
		item = item,
		key = item.key or itemDB:makeKey(item),
	}

	if request.count > 0 then
		self:queueRequest(request, callback)
	end

	if request.craft > 0 then
		item = Util.shallowCopy(item)
		item.requested = request.craft
		item.callback = callback
		self:requestCrafting(item)
	end

	return request
end

function Milo:emptyInventory()
	for i = 1, 16 do
		if turtle.getItemCount(i) > 0 then
			turtle.select(i)
			turtle.drop()
		end
	end
	turtle.select(1)
end

function Milo:eject(item, count)
	local total = 0
	while count > 0 do
		local amount = math.min(count, 16*(item.maxCount or 64))
		amount = self.context.storage:export(self.context.turtleInventory, nil, amount, item)
		if amount == 0 then
			break
		end
		total = total + amount
		count = count - amount

		--Sound.play('ui.button.click')
		Sound.play('entity.illusion_illager.death', .3)
		self:emptyInventory()
	end
	return total
end

function Milo:learnRecipe()
	local ingredients = self:getTurtleInventory()

	if not ingredients then
		return false, 'No recipe defined'
	end

	for _,v in pairs(ingredients) do
		if v.count > 1 then
			return false, 'Too many items'
		end
	end

	turtle.select(1)
	if not turtle.craft() then
		return false, 'Failed to craft'
	end

	local results = self:getTurtleInventory()
	if not results or not results[1] then
		return false, 'Failed to craft'
	end

	local maxCount
	local newRecipe = {
		ingredients = ingredients,
	}

	local numResults = 0
	for _,v in pairs(results) do
		if v.count > 0 then
			numResults = numResults + 1
		end
	end
	if numResults > 1 then
		for _,v1 in pairs(results) do
			for _,v2 in pairs(ingredients) do
				if v1.name == v2.name and
					v1.nbt == v2.nbt then
					if not newRecipe.crafingTools then
						newRecipe.craftingTools = { }
					end
					local tool = Util.shallowCopy(v2)

					--[[
					Turtles can only craft one item at a time using a tool :(
					]] -- Todo: check if this still applies
					maxCount = 1

					newRecipe.craftingTools[itemDB:makeKey(tool)] = true
					v1.craftingTool = true
					break
				end
			end
		end
	end

	local recipe
	for _,v in pairs(results) do
		if not v.craftingTool then
			recipe = v
			if maxCount then
				recipe.maxCount = maxCount
			end
			break
		end
	end

	if not recipe then
		return false, 'Unknown error'
	end

	newRecipe.count = recipe.count

	local key = itemDB:makeKey(recipe)
	if recipe.maxCount ~= 64 then
		newRecipe.maxCount = recipe.maxCount
	end
	for k,ingredient in pairs(Util.shallowCopy(ingredients)) do
		ingredients[k] = itemDB:makeKey(ingredient)
	end

	self:updateRecipe(key, newRecipe)

	return recipe
end

function Milo:updateRecipe(result, recipe)
	-- save the recipe
	if recipe then
		recipe = Util.shallowCopy(recipe)
		recipe.result = nil
	end
	self.context.userRecipes[result] = recipe
	Util.writeTable(Craft.USER_RECIPES, self.context.userRecipes)
	Craft.loadRecipes()
end

function Milo:saveMachineRecipe(recipe, result, machine)
	local key = itemDB:makeKey(result)

	-- save the recipe
	self.context.userRecipes[key] = recipe
	Util.writeTable(Craft.USER_RECIPES, self.context.userRecipes)

	-- save the machine association
	Craft.machineLookup[key] = machine
	Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)

	Craft.loadRecipes()
end

function Milo:mergeResources(t)
	t = Util.shallowCopy(t)

	for k,v in pairs(self.context.resources) do
		local item = t[k]
		if item then
			item = Util.shallowCopy(item)
		else
			item = itemDB:splitKey(k)
			item.count = 0
			item.key = k
		end
		Util.merge(item, v)
		t[k] = item
	end

	for k in pairs(Craft.recipes) do
		local item = t[k]
		if not item then
			item = itemDB:splitKey(k)
			item.count = 0
			item.key = k
		else
			item = Util.shallowCopy(item)
		end
		item.has_recipe = true
		t[k] = item
	end

	for key in pairs(Craft.machineLookup) do
		local item = t[key]
		if item then
			item = Util.shallowCopy(item)
			item.is_craftable = true
			t[key] = item
		end
	end

	for _,v in pairs(t) do
		if not v.displayName then
			v.displayName = itemDB:getName(v)
		end
		v.lname = v.displayName:lower()
	end

	return t
end

function Milo:saveResources()
	Util.writeTable(self.RESOURCE_FILE, self.context.resources)
end

-- Return a list of everything in the system
function Milo:listItems(forceRefresh, throttle)
	return forceRefresh and self.context.storage:refresh(throttle) or
		self.context.storage:listItems(throttle)
end

return Milo
