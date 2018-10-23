local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Lora   = require('lora')
local UI     = require('ui')
local Util   = require('util')

local device = _G.device
local turtle = _G.turtle

local context = Lora:getContext()

-- TODO: try networked module
local introspectionModule = device['plethora:introspection'] or
  error('Introspection module not found')

local function getTurtleInventory()
  local list = { }
  for i = 1,16 do
    list[i] = introspectionModule.getInventory().getItemMeta(i)
  end
  return list
end

local function learnRecipe()
  local ingredients = getTurtleInventory()
  local listingPage = UI:getPage('listing')

  if ingredients then
    turtle.select(1)
    if turtle.craft() then
      local results = getTurtleInventory()
      if results and results[1] then
        Lora:clearGrid()

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
                v1.nbtHash == v2.nbtHash and
                (v1.damage == v2.damage or
                  (v1.maxDamage > 0 and v2.maxDamage > 0 and
                   v1.damage ~= v2.damage)) then
                if not newRecipe.crafingTools then
                  newRecipe.craftingTools = { }
                end
                local tool = Util.shallowCopy(v2)
                if tool.maxDamage > 0 then
                  tool.damage = '*'
                end

                --[[
                Turtles can only craft one item at a time using a tool :(
                ]]--
                maxCount = 1

                newRecipe.craftingTools[Lora:uniqueKey(tool)] = true
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
          debug(results)
          debug(newRecipe)
          error('Failed - view system log')
        end

        newRecipe.count = recipe.count

        local key = Lora:uniqueKey(recipe)
        if recipe.maxCount ~= 64 then
          newRecipe.maxCount = recipe.maxCount
        end
        for k,ingredient in pairs(Util.shallowCopy(ingredients)) do
          if ingredient.maxDamage > 0 then
            -- ingredient.damage = '*'               -- I don't think this is right
          end
          ingredients[k] = Lora:uniqueKey(ingredient)
        end

        context.userRecipes[key] = newRecipe
        Util.writeTable(Lora.RECIPES_FILE, context.userRecipes)
        Craft.loadRecipes()

        local displayName = itemDB:getName(recipe)

        listingPage.statusBar.filter:setValue(displayName)
        listingPage.notification:success('Learned: ' .. displayName)
        listingPage.filter = displayName
        listingPage:refresh()
        listingPage.grid:draw()

        Lora:eject(recipe, recipe.count)
        return true
      end
    else
      listingPage.notification:error('Failed to craft', 3)
    end
  else
    listingPage.notification:error('No recipe defined', 3)
  end
end

local learnPage = UI.Dialog {
  height = 7, width = UI.term.width - 6,
  title = 'Learn Recipe',
  idField = UI.Text {
    x = 5,
    y = 3,
    width = UI.term.width - 10,
    value = 'Place recipe in turtle'
  },
  accept = UI.Button {
    x = -14, y = -3,
    text = 'Ok', event = 'accept',
  },
  cancel = UI.Button {
    x = -9, y = -3,
    text = 'Cancel', event = 'cancel'
  },
  statusBar = UI.StatusBar {
    status = 'Crafting paused'
  }
}

function learnPage:enable()
  Lora:pauseCrafting()
  self:focusFirst()
  UI.Dialog.enable(self)
end

function learnPage:disable()
  Lora:resumeCrafting()
  UI.Dialog.disable(self)
end

function learnPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()
  elseif event.type == 'accept' then
    if learnRecipe(self) then
      UI:setPreviousPage()
    end
  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

UI:addPage('learn', learnPage)
