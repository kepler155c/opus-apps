local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Util   = require('util')

local os     = _G.os
local term   = _G.term
local turtle = _G.turtle

local Lora = {
	RECIPES_FILE  = 'usr/config/recipes.db',
	RESOURCE_FILE = 'usr/config/resources.db',

	STATUS_INFO    = 'info',
	STATUS_WARNING = 'warning',
	STATUS_ERROR   = 'error',

	tasks = { },
	craftingStatus = { },
}

function Lora:init(context)
	self.context = context
end

function Lora:getContext()
	return self.context
end

function Lora:pauseCrafting()
	self.craftingPaused = true
end

function Lora:resumeCrafting()
	self.craftingPaused = false
end

function Lora:isCraftingPaused()
	return self.craftingPaused
end

function Lora:uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

function Lora:getCraftingStatus()
	return self.craftingStatus
end

function Lora:resetCraftingStatus()
	self.craftingStatus = { }
end

function Lora:updateCraftingStatus(list)
  for k,v in pairs(list) do
    self.craftingStatus[k] = v
  end

	self.context.jobList:updateList(self.craftingStatus)
end

function Lora:registerTask(task)
	table.insert(self.tasks, task)
end

function Lora:showError(msg)
	term.clear()
	self.context.jobList:showError()
	print(msg)
	print('rebooting in 5 secs')
	os.sleep(5)
	os.reboot()
end

function Lora:getItem(items, inItem, ignoreDamage, ignoreNbtHash)
  for _,item in pairs(items) do
    if item.name == inItem.name and
      (ignoreDamage or item.damage == inItem.damage) and
      (ignoreNbtHash or item.nbtHash == inItem.nbtHash) then
      return item
    end
  end
end

function Lora:getItemWithQty(res, ignoreDamage, ignoreNbtHash)
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

function Lora:clearGrid()
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

function Lora:eject(item, qty)
  local s, m = pcall(function()
    self.context.inventoryAdapter:provide(item, qty)
    turtle.emptyInventory()
  end)
  if not s and m then
    debug(m)
  end
end

function Lora:saveResources()
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

  Util.writeTable(Lora.RESOURCE_FILE, t)
end

-- Return a list of everything in the system
function Lora:listItems()
  for _ = 1, 5 do
    self.items = self.context.inventoryAdapter:listItems()
    if self.items then
      break
    end
--	    jobList:showError('Error - retrying in 3 seconds')
    os.sleep(3)
  end
  if not self.items then
		self:showError('Error - rebooting in 5 seconds')
  end

  return self.items
end

function Lora:addCraftingRequest(item, craftList, count)
  local key = self:uniqueKey(item)
  local request = craftList[key]
  if not craftList[key] then
    request = { name = item.name, damage = item.damage, nbtHash = item.nbtHash, count = 0 }
    request.displayName = itemDB:getName(request)
    craftList[key] = request
  end
  request.count = request.count + count
  return request
end

-- Craft
function Lora:craftItem(recipe, items, originalItem, craftList, count)
  local missing = { }
  local toCraft = Craft.getCraftableAmount(recipe, count, items, missing)
  if missing.name then
    originalItem.status = string.format('%s missing', itemDB:getName(missing.name))
    originalItem.statusCode = self.STATUS_WARNING
  end

  local crafted = 0

  if toCraft > 0 then
    crafted = Craft.craftRecipe(recipe, toCraft, self.context.inventoryAdapter)
    self:clearGrid()
    items = self:listItems()
    count = count - crafted
  end

  if count > 0 and items then
    local ingredients = Craft.getResourceList4(recipe, items, count)
    for _,ingredient in pairs(ingredients) do
      if ingredient.need > 0 then
        local item = self:addCraftingRequest(ingredient, craftList, ingredient.need)
        if Craft.findRecipe(item) then
          item.status = string.format('%s missing', itemDB:getName(ingredient))
          item.statusCode = self.STATUS_WARNING
        else
          item.status = 'no recipe'
          item.statusCode = self.STATUS_ERROR
        end
      end
    end
  end
  return crafted
end

-- Craft as much as possible regardless if all ingredients are available
function Lora:forceCraftItem(inRecipe, items, originalItem, craftList, inCount)
  local summed = { }
  local throttle = Util.throttle()

  local function sumItems(recipe, count)
    count = math.ceil(count / recipe.count)
    local craftable = count

    for key,iqty in pairs(Craft.sumIngredients(recipe)) do
      throttle()
      local item = itemDB:splitKey(key)
      local summedItem = summed[key]
      if not summedItem then
        summedItem = Util.shallowCopy(item)
        summedItem.recipe = Craft.findRecipe(item)
        summedItem.count = Craft.getItemCount(items, key)
        summedItem.need = 0
        summedItem.used = 0
        summedItem.craftable = 0
        summed[key] = summedItem
      end

      local total = count * iqty                           -- 4 * 2
      local used = math.min(summedItem.count, total)       -- 5
      local need = total - used                            -- 3

      if recipe.craftingTools and recipe.craftingTools[key] then
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
        summedItem.count = summedItem.count - used
        summedItem.used = summedItem.used + used
      end

      if need > 0 then
        if not summedItem.recipe then
          craftable = math.min(craftable, math.floor(used / iqty))
          summedItem.need = summedItem.need + need
        else
          local c = sumItems(summedItem.recipe, need) -- 4
          craftable = math.min(craftable, math.floor((used + c) / iqty))
          summedItem.craftable = summedItem.craftable + c
        end
      end
    end
    if craftable > 0 then
      craftable = Craft.craftRecipe(recipe, craftable * recipe.count,
				self.context.inventoryAdapter) / recipe.count
      self:clearGrid()
    end

    return craftable * recipe.count
  end

  local count = sumItems(inRecipe, inCount)

  if count < inCount then
    for _,ingredient in pairs(summed) do
      if ingredient.need > 0 then
        local item = self:addCraftingRequest(ingredient, craftList, ingredient.need)
        if Craft.findRecipe(item) then
          item.status = string.format('%s missing', itemDB:getName(ingredient))
          item.statusCode = self.STATUS_WARNING
        else
          item.status = '(no recipe)'
          item.statusCode = self.STATUS_ERROR
        end
      end
    end
  end
  return count
end

function Lora:craft(recipe, items, item, craftList)
  item.status = nil
  item.statusCode = nil
  item.crafted = 0

  if self:isCraftingPaused() then
    return
  end

  if not self:clearGrid() then
    item.status = 'Grid obstructed'
    item.statusCode = self.STATUS_ERROR
    return
  end

  if item.forceCrafting then
    item.crafted = self:forceCraftItem(recipe, items, item, craftList, item.count)
  else
    item.crafted = self:craftItem(recipe, items, item, craftList, item.count)
  end
end

function Lora:craftItems(craftList)
  for _,key in pairs(Util.keys(craftList)) do
    local item = craftList[key]
    local recipe = Craft.recipes[key]
    if recipe then
      self:craft(recipe, self:listItems(), item, craftList)
    elseif not self.context.controllerAdapter then
      item.status = '(no recipe)'
      item.statusCode = self.STATUS_ERROR
    end
  end
end

return Lora
