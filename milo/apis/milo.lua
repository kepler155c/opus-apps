local Config = require('config')
local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Util   = require('util')

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

function Milo:requestCrafting(item)
	local key = Milo:uniqueKey(item)

	if not self.context.craftingQueue[key] then
		item.ingredients = {
			[ key ] = item
		}
		item.crafted = 0
		self.context.craftingQueue[key] = item
	end
end

function Milo:pauseCrafting()
	self.craftingPaused = true
	Milo:showError('Crafting Paused')
end

function Milo:resumeCrafting()
	self.craftingPaused = false
end

function Milo:isCraftingPaused()
	return self.craftingPaused
end

function Milo:getState(key)
	if not self.state then
		self.state = { }
		Config.load('milo.state', self.state)
	end
	return self.state[key]
end

function Milo:setState(key, value)
	if not self.state then
		self.state = { }
		Config.load('milo.state', self.state)
	end
	self.state[key] = value
	Config.update('milo.state', self.state)
end

function Milo:uniqueKey(item)
	return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

function Milo:resetCraftingStatus()
	self.context.storage.activity = { }

	for _,key in pairs(Util.keys(self.context.craftingQueue)) do
		local item = self.context.craftingQueue[key]
		if item.crafted >= item.count then
			self.context.craftingQueue[key] = nil
		end
	end
end

function Milo:registerTask(task)
	table.insert(self.context.tasks, task)
end

function Milo:showError(msg)
	self.context.jobMonitor:showError(msg)
end

function Milo:getItem(items, inItem, ignoreDamage, ignoreNbtHash)
	for _,item in pairs(items) do
		if item.name == inItem.name and
			(ignoreDamage or item.damage == inItem.damage) and
			(ignoreNbtHash or item.nbtHash == inItem.nbtHash) then
			return item
		end
	end
end

function Milo:getItemWithQty(res, ignoreDamage, ignoreNbtHash)
	local items = self:listItems()
	local item = self:getItem(items, res, ignoreDamage, ignoreNbtHash)

	if item and (ignoreDamage or ignoreNbtHash) then
		local count = 0

		for _,v in pairs(items) do
			if item.name == v.name and
				(ignoreDamage or item.damage == v.damage) and
				(ignoreNbtHash or item.nbtHash == v.nbtHash) then
				count = count + v.count
			end
		end
		item.count = count
	end

	return item
end

function Milo:getMatches(items, item, ignoreDamage, ignoreNbtHash)
	local t = { }

	if not ignoreDamage and not ignoreNbtHash then
		local key = item.key or Milo:uniqueKey(item)
		local e = items[key]
		if e then
			t[key] = Util.shallowCopy(e)
		end

	else
		for k,v in pairs(items) do
			if item.name == v.name and
				(ignoreDamage or item.damage == v.damage) and
				(ignoreNbtHash or item.nbtHash == v.nbtHash) then
				local e = t[k]
				if not e then
					t[k] = Util.shallowCopy(v)
				else
					e.count = e.count + item.count
				end
			end
		end
	end

	return t
end

function Milo:clearGrid()
	turtle.eachFilledSlot(function(slot)
		self.context.storage:import(self.context.localName, slot.index, slot.count, slot)
	end)

	for i = 1, 16 do
		if turtle.getItemCount(i) ~= 0 then
			return false
		end
	end
	return true
end

function Milo:getTurtleInventory()
	local list = { }

	for i = 1,16 do
		local item = self.context.introspectionModule.getInventory().getItemMeta(i)
		if item then
			if not itemDB:get(item) then
				itemDB:add(item)
			end
			list[i] = item
		end
	end
	itemDB:flush()
	return list
end

function Milo:xxx(item, count)
	return self:provideItem(item, count, function(providable, currentCount)
		-- return the current amount in the system
		return currentCount - self:eject(item, providable)
	end)
end

function Milo:provideItem(item, count, callback)
	if count <= 0 then
		return 0
	end

	local current = Milo:getItem(Milo:listItems(), item) or { count = 0 }
	local toCraft = count - math.min(current.count, count)

	if toCraft > 0 then
		local recipe = Craft.findRecipe(self:uniqueKey(item))
		if not recipe then
			toCraft = 0
		else
			-- if you ask for 1 stick, getCraftableAmount will return 4 (obviously)
			toCraft = math.min(toCraft, Craft.getCraftableAmount(recipe, toCraft, Milo:listItems(), { }))
		end
	end

	if toCraft == 0 then
		return callback(math.min(count, current.count), current.count)
--		return current.count - self:eject(item, math.min(count, current.count))
	end

	item = Util.shallowCopy(item)
	item.count = current.count + toCraft
	item.eject = callback
	self:requestCrafting(item)
	item.crafted = current.count

	return current.count
end

function Milo:eject(item, count)
	count = self.context.storage:provide(item, count)
	turtle.emptyInventory()
	return count
end

function Milo:saveMachineRecipe(recipe, result, machine)
	local key = Milo:uniqueKey(result)

	-- save the recipe
	self.context.userRecipes[key] = recipe
	Util.writeTable(Craft.USER_RECIPES, self.context.userRecipes)

	-- save the machine association
	Craft.machineLookup[key] = machine
	Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)

	Craft.loadRecipes()
end

function Milo:mergeResources(t)
	for _,v in pairs(self.context.resources) do
		local item = self:getItem(t, v)
		if item then
			Util.merge(item, v)
		else
			item = Util.shallowCopy(v)
			item.count = 0
			item.key = self:uniqueKey(v)
--			table.insert(t, item)
			t[item.key] = item
		end
	end

	for k in pairs(Craft.recipes) do
		local v = itemDB:splitKey(k)
		local item = self:getItem(t, v)
		if not item then
			item = Util.shallowCopy(v)
			item.count = 0
			item.key = self:uniqueKey(v)
			t[item.key] = item
--			table.insert(t, item)
		end
		item.has_recipe = true
	end

	for key in pairs(Craft.machineLookup) do
		local item = t[key]
		if item then
			item.is_craftable = true
		end
	end

	for _,v in pairs(t) do
		if not v.displayName then
			v.displayName = itemDB:getName(v)
		end
		v.lname = v.displayName:lower()
	end
end

function Milo:saveResources()
	local t = { }

	for k,v in pairs(self.context.resources) do
		v = Util.shallowCopy(v)
		local keys = Util.transpose({ 'auto', 'low', 'limit',
									'ignoreDamage', 'ignoreNbtHash',
									 'rsControl', 'rsDevice', 'rsSide' })

		for _,key in pairs(Util.keys(v)) do
			if not keys[key] then
				v[key] = nil
			end
		end
		if not Util.empty(v) then
			t[k] = v
		end
	end

	Util.writeTable(self.RESOURCE_FILE, t)
end

-- Return a list of everything in the system
function Milo:listItems()
	return self.context.storage:listItems()
end

-- force a full rescan of chests
function Milo:refreshItems()
	return self.context.storage:refresh()
end

return Milo
