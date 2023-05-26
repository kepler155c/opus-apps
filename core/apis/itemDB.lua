local Map     = require('opus.map')
local nameDB  = require('core.nameDB')
local TableDB = require('core.tableDB')
local Util    = require('opus.util')

local itemDB = TableDB({ fileName = 'usr/config/items.db' })

local function safeString(text)
	local val = text:byte(1)

	if val < 32 or val > 128 then

		local newText = { }
		local skip = 0
		for i = 1, #text do
			val = text:byte(i)
			if val == 167 then
				skip = 2
			end
			if skip > 0 then
				skip = skip - 1
			else
				if val >= 32 and val <= 128 then
					newText[#newText + 1] = val
				end
			end
		end
		return string.char(unpack(newText))
	end

	return text
end

function itemDB:makeKey(item)
	if not item then error('itemDB:makeKey: item is required', 2) end
	return table.concat({ item.name, item.nbt }, ':')
end

function itemDB:splitKey(key, item)
	item = item or { }

	local t = Util.split(key, '(.-):')

	if t[3] then
		item.nbt = t[3]
		t[3] = nil
	end

	item.name = table.concat(t, ':')

	return item
end

function itemDB:get(key, populateFn)
	if not key then error('itemDB:get: key is required', 2) end
	if type(key) == 'string' then
		key = self:splitKey(key)
	else
		key = Util.shallowCopy(key)
	end

	local item = self:_get(key)
	if not item and populateFn then
		item = populateFn()
		if item then
			item = self:add(item)
		end
	end

	return item and Util.merge(key, item)
end

function itemDB:_get(key)
	if not key then error('itemDB:get: key is required', 2) end
	if type(key) == 'string' then
		key = self:splitKey(key)
	end

	local item = TableDB.get(self, self:makeKey(key))
	if item then
		return item
	end

	for k,item in pairs(self.data) do
		if key.name == item.name and
			 key.nbt == item.nbt then
			item = Util.shallowCopy(item)
			return item
		end
	end

	if key.nbt then
		item = self:get({ name = key.name })

		if item and item.ignoreNBT then
			item = Util.shallowCopy(item)
			item.nbt = key.nbt
			return item
		end
	end
end

local function formatTime(t)
	local m = math.floor(t/60)
	local s = t % 60
	if s < 10 then
		s = '0' .. s
	end

	return m .. ':' .. s
end

--[[
	If the base item contains an NBT hash, then the NBT hash uniquely
	identifies this item.
]]--
function itemDB:add(baseItem)
	local nItem = {
		name    = baseItem.name,
		nbt = baseItem.nbt,
	}
--  if detail.maxDamage > 0 then
--    nItem.damage = '*'
--  end

	nItem.displayName = safeString(baseItem.displayName)
	nItem.maxCount = baseItem.maxCount

	-- enchanted items
	if baseItem.enchantments then
		if nItem.name == 'minecraft:enchanted_book' then
			nItem.displayName = 'Book: '
		else
			nItem.displayName = nItem.displayName .. ': '
		end
		for k, v in ipairs(baseItem.enchantments) do
			if k > 1 then
				nItem.displayName = nItem.displayName .. ', '
			end
			nItem.displayName = nItem.displayName .. v.displayName
		end

	-- turtles / computers / etc
	elseif baseItem.computer then
		-- a turtle's NBT is updated constantly
		-- update the cache with the new NBT
		if baseItem.computer.id then
			Map.removeMatches(self.data, { name = nItem.name, displayName = nItem.displayName })
		end
		nItem.displayName = baseItem.computer.label or baseItem.displayName

		-- disks
	elseif baseItem.media then
		-- don't ignore nbt... as disks can be labeled
		if baseItem.media.recordTitle then
			nItem.displayName = nItem.displayName .. ': ' .. baseItem.media.recordTitle
		end

	-- potions
	elseif nItem.name == 'minecraft:potion' or nItem.name == 'minecraft:lingering_potion' then
		if baseItem.effects then
			local effect = baseItem.effects[1]
			if effect.amplifier == 1 then
				nItem.displayName = nItem.displayName .. ' II'
			end
			if effect.duration and effect.duration > 0 then
				nItem.displayName = string.format('%s (%s)', nItem.displayName, formatTime(effect.duration))
			end
		end

	else
		for k,item in pairs(self.data) do
			if nItem.name == item.name and
				 nItem.displayName == item.displayName then

				if nItem.nbt ~= item.nbt then
					nItem.nbt = nil
					nItem.ignoreNBT = true
					self.data[k] = nil
					break
				end
			end
		end
	end

	TableDB.add(self, self:makeKey(nItem), nItem)
	nItem = Util.shallowCopy(nItem)
	nItem.nbt = baseItem.nbt

	return nItem
end

-- Accepts: "minecraft:stick:0" or { name = 'minecraft:stick', damage = 0 }
function itemDB:getName(item)
	if type(item) == 'string' then
		item = self:splitKey(item)
	end

	local detail = self:get(item)
	if detail then
		return detail.displayName
	end

	-- fallback to nameDB
	local strId = self:makeKey(item)
	local name = nameDB.data[strId]
	if not name then
		name = nameDB.data[self:makeKey({ name = item.name, nbt = item.nbt })]
	end
	return name or strId
end

function itemDB:getMaxCount(item)
	local detail = self:get(item)
	return detail and detail.maxCount or 64
end

function itemDB:load()
	TableDB.load(self)

	for key,item in pairs(self.data) do
		self:splitKey(key, item)
		item.maxCount = item.maxCount or 64
	end
end

function itemDB:flush()
	if self.dirty then
		local t = { }
		for k,v in pairs(self.data) do
			v = Util.shallowCopy(v)
			v.name = nil
			v.nbt = nil
			if v.maxCount == 64 then
				v.maxCount = nil
			end
			t[k] = v
		end

		Util.writeTable(self.fileName, t)
		self.dirty = false
	end
end

itemDB:load()

return itemDB
