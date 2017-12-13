local Util   = require('util')

local fs     = _G.fs
local turtle = _G.turtle

local RECIPES_DIR = 'usr/etc/recipes'

local Craft = { }

local function clearGrid(inventoryAdapter)
  for i = 1, 16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      inventoryAdapter:insert(i, count)
      if turtle.getItemCount(i) ~= 0 then
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

local function getItemCount(items, key)
  local item = splitKey(key)
  for _,v in pairs(items) do
    if v.name == item.name and
       (not item.damage or v.damage == item.damage) and
       v.nbtHash == item.nbtHash then
      return v.count
    end
  end
  return 0
end

local function turtleCraft(recipe, qty, inventoryAdapter)
  clearGrid(inventoryAdapter)

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
      return false
    end
  end

  return turtle.craft()
end

function Craft.loadRecipes()
  Craft.recipes = Util.readTable(fs.combine(RECIPES_DIR, 'minecraft.db')) or { }

  local files = fs.list('usr/etc/recipes')
  table.sort(files)
  Util.removeByValue(files, 'minecraft.db')

  for _,file in ipairs(files) do
    local recipes = Util.readTable(fs.combine(RECIPES_DIR, file))
    Util.merge(Craft.recipes, recipes)
  end

  local recipes = Util.readTable('usr/config/recipes.db') or { }
  Util.merge(Craft.recipes, recipes)
end

function Craft.sumIngredients(recipe)
  -- produces { ['minecraft:planks:0'] = 8 }
  local t = { }
  for _,item in pairs(recipe.ingredients) do
    t[item] = (t[item] or 0) + 1
  end
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

  count = math.ceil(count / recipe.count)

  local maxCount = recipe.maxCount or math.floor(64 / recipe.count)
  local summedItems = Craft.sumIngredients(recipe)

  for key,icount in pairs(summedItems) do
    local itemCount = getItemCount(items, key)
    if itemCount < icount * count then
      local irecipe = Craft.recipes[key]
      if irecipe then
        local iqty = icount * count - itemCount
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

  turtle.select(1)
  return crafted * recipe.count
end

-- given a certain quantity, return how many of those can be crafted
function Craft.getCraftableAmount(recipe, count, items, missing)
  local function sumItems(recipe, summedItems, count)
    local canCraft = 0

    for _ = 1, count do
      for _,item in pairs(recipe.ingredients) do
        local summedItem = summedItems[item] or getItemCount(items, item)

        local irecipe = Craft.recipes[item]
        if irecipe and summedItem <= 0 then
          summedItem = summedItem + sumItems(irecipe, summedItems, 1)
        end
        if summedItem <= 0 then
          if missing then
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

  return sumItems(recipe, { }, math.ceil(count / recipe.count))
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
