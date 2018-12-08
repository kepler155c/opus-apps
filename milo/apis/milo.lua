local Config = require('config')
local Craft  = require('craft2')
local itemDB = require('itemDB')
local Sound  = require('sound')
local Util   = require('util')

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

function Milo:splitKey(key)
	return itemDB:splitKey(key)
end

function Milo:resetCraftingStatus()
	self.context.storage.activity = { }

	for _,key in pairs(Util.keys(self.context.craftingQueue)) do
		local item = self.context.craftingQueue[key]
		if item.crafted >= item.requested then
			self.context.craftingQueue[key] = nil
		end
	end
end

function Milo:registerTask(task)
	table.insert(self.context.tasks, task)
end

function Milo:getItem(items, inItem, ignoreDamage, ignoreNbtHash)
	if not ignoreDamage and not ignoreNbtHash then
		return items[inItem.key or self:uniqueKey(inItem)]
	end

	for _,item in pairs(items) do
		if item.name == inItem.name and
			(ignoreDamage or item.damage == inItem.damage) and
			(ignoreNbtHash or item.nbtHash == inItem.nbtHash) then
			return item
		end
	end
end

-- returns a list of items that matches along with a total count
function Milo:getMatches(item, flags)
	local t = { }
	local count = 0
	local items = self:listItems()

	if not flags.ignoreDamage and not flags.ignoreNbtHash then
		local key = item.key or Milo:uniqueKey(item)
		local v = items[key]
		if v then
			t[key] = Util.shallowCopy(v)
			count = v.count
		end

	else
		for key,v in pairs(items) do
			if item.name == v.name and
				(flags.ignoreDamage or item.damage == v.damage) and
				(flags.ignoreNbtHash or item.nbtHash == v.nbtHash) then

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

	for i in pairs(self.context.turtleInventory.adapter.list()) do
		local item = self.context.turtleInventory.adapter.getItemMeta(i)
		if item and not itemDB:get(item) then
			itemDB:add(item)
		end
		list[i] = item
	end

	itemDB:flush()
	return list
end

function Milo:requestCrafting(item)
	local key = Milo:uniqueKey(item)

	if not self.context.craftingQueue[key] then
		item.crafted = 0
		item.pending = { }
		item.key = key
		self.context.craftingQueue[key] = item
		os.queueEvent('milo_cycle')
	end
end

-- queue up an action that reliees on the crafting grid
function Milo:queueRequest(request, callback)
	if Util.empty(self.context.queue) then
		os.queueEvent('milo_queue')
	end
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
	local current = Milo:getItem(Milo:listItems(), item) or { count = 0 }

	if count <= 0 then
		return {
			requested = 0,
			craft = 0,
			count = 0,
			current = current.count,
			item = item,
			key = item.key or Milo:uniqueKey(item),
		}
	end

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

	local request = {
		requested = count,
		craft = toCraft,
		count = math.min(count, current.count),
		current = current.count,
		item = item,
		key = item.key or Milo:uniqueKey(item),
	}

	if request.count > 0 then
		Milo:queueRequest(request, callback)
	end

	if request.craft > 0 then
		item = Util.shallowCopy(item)
		item.requested = request.craft
		item.callback = callback
		self:requestCrafting(item)
	end

	return request
end

function Milo:eject(item, count)
	count = self.context.storage:export(self.context.turtleInventory, nil, count, item)
	Sound.play('ui.button.click')
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
	t = Util.shallowCopy(t)

	for k,v in pairs(self.context.resources) do
		local key = itemDB:splitKey(k)
		local item = self:getItem(t, key)
		if item then
			item = Util.shallowCopy(item)
		else
			item = key
			item.count = 0
			item.key = k
		end
		Util.merge(item, v)
		item.resource = v
		t[item.key] = item
	end

	for k in pairs(Craft.recipes) do
		local v = itemDB:splitKey(k)
		local item = self:getItem(t, v)
		if not item then
			item = v
			item.count = 0
			item.key = k
		else
			item = Util.shallowCopy(item)
		end
		t[item.key] = item
		item.has_recipe = true
	end

	for key in pairs(Craft.machineLookup) do
		local item = t[key]
		if item then
			item = Util.shallowCopy(item)
			item.is_craftable = true
			t[item.key] = item
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
