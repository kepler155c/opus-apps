local Craft  = require('craft2')
local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')

local colors = _G.colors

local recipeTab = UI.Window {
  tabTitle = 'Recipe',
  index = 2,
  backgroundColor = colors.cyan,
  grid = UI.ScrollingGrid {
    x = 2, ex = -2, y = 2, ey = -4,
    disableHeader = true,
    columns = {
      { heading = 'Slot', key = 'slot', width = 2 },
      { heading = 'Key', key = 'key' },
    },
    sortColumn = 'slot',
  },
  ignoreNBT = UI.Button {
    x = -13, y = -2,
    text = 'Ignore NBT', event = 'ignore_nbt',
  },
}

function recipeTab:setItem(item)
  self.item = item
  self.recipe = Craft.findRecipe(self.item)

  self.parent:setActive(self, self.recipe)

  local t = { }
  if self.recipe then
    for k, v in pairs(self.recipe.ingredients) do
      table.insert(t, {
        slot = k,
        key = v,
      })
    end
  end
  self.grid:setValues(t)
end

function recipeTab:eventHandler(event)
  if event.type == 'ignore_nbt' then
    local selected = self.grid:getSelected()
    local item = itemDB:splitKey(selected.key)
    item.nbtHash = nil
    selected.key = itemDB:makeKey(item)
    self.grid:draw()

    self.recipe.ingredients = { }
    for _, v in pairs(self.grid.values) do
      self.recipe.ingredients[v.slot] = v.key
    end

    Milo:updateRecipe(self.recipe.result, self.recipe)
    self:emit({ type = 'info_message', message = 'Recipe updated' })

    return true
  end
end

return recipeTab
