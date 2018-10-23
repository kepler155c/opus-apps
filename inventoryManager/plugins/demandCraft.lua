local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Lora   = require('lora')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors

local demandCrafting = { }

local craftPage = UI.Page {
  titleBar = UI.TitleBar { },
  wizard = UI.Wizard {
    y = 2, ey = -2,
    pages = {
      quantity = UI.Window {
        index = 1,
        text = UI.Text {
          x = 6, y = 3,
          value = 'Quantity',
        },
        count = UI.TextEntry {
          x = 15, y = 3, width = 10,
          limit = 6,
          value = 1,
        },
        ejectText = UI.Text {
          x = 6, y = 4,
          value = 'Eject',
        },
        eject = UI.Chooser {
          x = 15, y = 4, width = 7,
          value = true,
          nochoice = 'No',
          choices = {
            { name = 'Yes', value = true },
            { name = 'No', value = false },
          },
        },
      },
      resources = UI.Window {
        index = 2,
        grid = UI.ScrollingGrid {
          y = 2, ey = -2,
          columns = {
            { heading = 'Name',  key = 'displayName' },
            { heading = 'Total', key = 'total'      , width = 5 },
            { heading = 'Used',  key = 'used'       , width = 5 },
            { heading = 'Need',  key = 'need'       , width = 5 },
          },
          sortColumn = 'displayName',
        },
      },
    },
  },
}

function craftPage:enable(item)
  self.item = item
  self:focusFirst()
  self.titleBar.title = itemDB:getName(item)
--  self.wizard.pages.quantity.eject.value = true
  UI.Page.enable(self)
end

function craftPage.wizard.pages.resources.grid:getDisplayValues(row)
  local function dv(v)
    if v == 0 then
      return ''
    end
    return Util.toBytes(v)
  end
  row = Util.shallowCopy(row)
  row.total = Util.toBytes(row.total)
  row.used = dv(row.used)
  row.need = dv(row.need)
  return row
end

function craftPage.wizard.pages.resources.grid:getRowTextColor(row, selected)
  if row.need > 0 then
    return colors.orange
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function craftPage.wizard:eventHandler(event)
  if event.type == 'nextView' then
    local count = tonumber(self.pages.quantity.count.value)
    if not count or count <= 0 then
      self.pages.quantity.count.backgroundColor = colors.red
      self.pages.quantity.count:draw()
      return false
    end
    self.pages.quantity.count.backgroundColor = colors.black
  end
  return UI.Wizard.eventHandler(self, event)
end

function craftPage.wizard.pages.resources:enable()
  local items = Lora:listItems()
  local count = tonumber(self.parent.quantity.count.value)
  local recipe = Craft.findRecipe(craftPage.item)
  if recipe then
    local ingredients = Craft.getResourceList4(recipe, items, count)
    for _,v in pairs(ingredients) do
      v.displayName = itemDB:getName(v)
    end
    self.grid:setValues(ingredients)
  else
    self.grid:setValues({ })
  end
  return UI.Window.enable(self)
end

function craftPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()

  elseif event.type == 'accept' then
    local key = Lora:uniqueKey(self.item)
    demandCrafting[key] = Util.shallowCopy(self.item)
    demandCrafting[key].count = tonumber(self.wizard.pages.quantity.count.value)
    demandCrafting[key].ocount = demandCrafting[key].count
    demandCrafting[key].forceCrafting = true
    demandCrafting[key].eject = self.wizard.pages.quantity.eject.value == true
    UI:setPreviousPage()
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local demandCraftingTask = {
  priority = 20,
}

function demandCraftingTask:cycle(context)
  local demandCrafted = { }

  -- look directly at the adapter import activity to determine
  -- if the item was imported into storage from any source.
  -- The item does NOT need to come from the machine that did
  -- the crafting.
  for _,key in pairs(Util.keys(demandCrafting)) do
    local item = demandCrafting[key]

    local imported = context.inventoryAdapter.activity[key]
    if imported then
      item.crafted = math.min(imported, item.count)
      item.count = math.max(0, item.count - item.crafted)
      context.inventoryAdapter.activity[key] = imported - item.crafted
    end
    demandCrafted[key] = item
  end

  if Util.size(demandCrafted) > 0 then
    Lora:craftItems(demandCrafted)
  end

  for _,key in pairs(Util.keys(demandCrafting)) do
    local item = demandCrafting[key]
    if item.crafted then
      item.count = math.max(0, item.count - item.crafted)
      if item.count <= 0 then
        item.statusCode = 'success'
        demandCrafting[key] = nil
        if item.eject then
          Lora:eject(item, item.ocount)
        end
      end
    end
  end
end

UI:addPage('craft', craftPage)
Lora:registerTask(demandCraftingTask)
