local Config = require('config')
local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Util   = require('util')

local turtle = _G.turtle

local Milo = {
	RECIPES_FILE  = 'usr/config/recipes.db',
	RESOURCE_FILE = 'usr/config/resources.db',
}

function Milo:init(context)
	self.context = context
end

function Milo:getContext()
	return self.context
end

function Milo:requestCrafting(item)
	local key = Milo:uniqueKey(item)

	if not self.context.craftingQueue[key] then
		item.ingredients = { }
		--[[
			count   = requested amount,
			crafted = amount that has been crafted
		]]
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

	-- todo: move to end of processing tasks ?
	-- what if someone hoppers in items ? -- this shouldnt be allowed
	-- all items must come in via pullItems
	self.context.inventoryAdapter.activity = { }

	for _,key in pairs(Util.keys(self.context.craftingQueue)) do
		local item = self.context.craftingQueue[key]
		if item.crafted >= item.count then
			debug('removing:')
			debug(item)
			self.context.craftingQueue[key] = nil
		end
	end
end

function Milo:registerTask(task)
	table.insert(self.context.tasks, task)
end

function Milo:showError(msg)
	self.context.jobList:showError(msg)
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

function Milo:clearGrid()
	local function clear()
		turtle.eachFilledSlot(function(slot)
			self.context.inventoryAdapter:insert(slot.index, slot.count, nil, slot)
		end)

		for i = 1, 16 do
			if turtle.getItemCount(i) ~= 0 then
				return false
			end
		end
		return true
	end
	return clear() or clear()
end

function Milo:eject(item, qty)
	local s, m = pcall(function()
		self.context.inventoryAdapter:provide(item, qty)
		turtle.emptyInventory()
	end)
	if not s and m then
		debug(m)
	end
end

function Milo:mergeResources(t)
	for _,v in pairs(self.context.resources) do
		local item = self:getItem(t, v)
		if item then
			Util.merge(item, v)
		else
			item = Util.shallowCopy(v)
			item.count = 0
			table.insert(t, item)
		end
	end

	for k in pairs(Craft.recipes) do
		local v = itemDB:splitKey(k)
		local item = self:getItem(t, v)
		if not item then
			item = Util.shallowCopy(v)
			item.count = 0
			table.insert(t, item)
		end
		item.has_recipe = true
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
	self.items = self.context.inventoryAdapter:listItems()
	return self.items
end

return Milo
