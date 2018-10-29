local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Milo   = require('milo')
local Util   = require('util')

local context = Milo:getContext()

local craftTask = {
  name = 'crafting',
  priority = 70,
}

function craftTask:craftItem(recipe, item, count)
  Craft.craftRecipe(recipe, count, context.storage, item)
  Milo:clearGrid()
end

-- Craft as much as possible regardless if all ingredients are available
function craftTask:forceCraftItem(inRecipe, originalItem, inCount)
  local summed = { }
  local items = Milo:listItems()
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
        context.storage, originalItem) / recipe.count
      Milo:clearGrid()
    end

    return craftable * recipe.count
  end

  return sumItems(inRecipe, inCount)
end

function craftTask:craft(recipe, item)
  if Milo:isCraftingPaused() then
    return
  end

  if item.forceCrafting then
    self:forceCraftItem(recipe, item, item.count - item.crafted)
  else
    self:craftItem(recipe, item, item.count - item.crafted)
  end
end

function craftTask:cycle()
  for _,key in pairs(Util.keys(context.craftingQueue)) do
    local item = context.craftingQueue[key]
    if item.count - item.crafted > 0 then
      local recipe = Craft.findRecipe(key)
      if recipe then
        self:craft(recipe, item)
        if item.eject and item.crafted >= item.count then
          if type(item.eject) == 'boolean' then
            Milo:eject(item, item.count)
          else
            item.eject(item.count, 0) -- unknown amount in system
          end
        end
      elseif not context.controllerAdapter then
        item.status = '(no recipe)'
        item.statusCode = Craft.STATUS_ERROR
        item.crafted = 0
      end
    end
  end
end

Milo:registerTask(craftTask)