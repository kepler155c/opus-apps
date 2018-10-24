local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local os     = _G.os

local context = Milo:getContext()

local function queue(fn)
  while Milo:isCraftingPaused() do
    os.sleep(1)
  end
  fn()
end

local function filterItems(t, filter, displayMode)
  if filter or displayMode > 0 then
    local r = { }
    if filter then
      filter = filter:lower()
    end
    for _,v in pairs(t) do
      if not filter or string.find(v.lname, filter, 1, true) then
        if not displayMode or
          displayMode == 0 or
          displayMode == 1 and v.count > 0 or
          displayMode == 2 and v.has_recipe then
          table.insert(r, v)
        end
      end
    end
    return r
  end
  return t
end

local listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Learn',   event = 'learn'   },
      { text = 'Forget',  event = 'forget'  },
      { text = 'Craft',   event = 'craft'   },
      { text = 'Refresh', event = 'refresh', x = -9 },
    },
  },
  grid = UI.Grid {
    y = 2, ey = -2,
    columns = {
      { heading = ' Qty',  key = 'count'       , width = 4, justify = 'right' },
      { heading = 'Name', key = 'displayName' },
      { heading = 'Min',  key = 'low'         , width = 4 },
      { heading = 'Max',  key = 'limit'       , width = 4 },
    },
    sortColumn = 'displayName',
  },
  statusBar = UI.StatusBar {
    filter = UI.TextEntry {
      x = 1, ex = -4,
      limit = 50,
      shadowText = 'filter',
      shadowTextColor = colors.gray,
      backgroundColor = colors.cyan,
      backgroundFocusColor = colors.cyan,
      accelerators = {
        [ 'enter' ] = 'craft',
      },
    },
    display = UI.Button {
      x = -3,
      event = 'toggle_display',
      value = 0,
      text = 'A',
    },
  },
  notification = UI.Notification(),
  accelerators = {
    r = 'refresh',
    q = 'quit',
    [ 'control-e' ] = 'eject',
    [ 'control-s' ] = 'eject_stack',
    [ 'control-1' ] = 'eject_1',
    [ 'control-2' ] = 'eject_1',
    [ 'control-3' ] = 'eject_1',
    [ 'control-4' ] = 'eject_1',
    [ 'control-5' ] = 'eject_1',
    [ 'control-6' ] = 'eject_1',
    [ 'control-7' ] = 'eject_1',
    [ 'control-8' ] = 'eject_1',
    [ 'control-9' ] = 'eject_1',
    [ 'control-0' ] = 'eject_1',
    [ 'control-m' ] = 'machines',
    [ 'control-l' ] = 'resume',
  },
  displayMode = 0,
}

function listingPage.statusBar:draw()
  return UI.Window.draw(self)
end

function listingPage.grid:getRowTextColor(row, selected)
  if row.is_craftable then
    return colors.yellow
  end
  if row.has_recipe then
    return colors.cyan
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function listingPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.count = row.count > 0 and Util.toBytes(row.count) or ''
  if row.low then
    row.low = Util.toBytes(row.low)
  end
  if row.limit then
    row.limit = Util.toBytes(row.limit)
  end
  return row
end

function listingPage:eventHandler(event)
  if event.type == 'quit' then
    UI:exitPullEvents()

  elseif event.type == 'resume' then
    Milo:resumeCrafting()

  elseif event.type == 'eject' then
    local item = self.grid:getSelected()
    if item then
      queue(function() Milo:eject(item, 1) end)
    end

  elseif event.type == 'eject_stack' then
    local item = self.grid:getSelected()
    if item then
      queue(function() Milo:eject(item, itemDB:getMaxCount(item)) end)
    end

  elseif event.type == 'machines' then
    UI:setPage('machines')

  elseif event.type == 'details' or event.type == 'grid_select_right' then
    local item = self.grid:getSelected()
    if item then
      UI:setPage('item', item)
    end

  elseif event.type == 'refresh' then
    self:refresh()
    self.grid:draw()
    self.statusBar.filter:focus()

  elseif event.type == 'toggle_display' then
    local values = {
      [0] = 'A',
      [1] = 'I',
      [2] = 'C',
    }

    event.button.value = (event.button.value + 1) % 3
    self.displayMode = event.button.value
    event.button.text = values[event.button.value]
    event.button:draw()
    self:applyFilter()
    self.grid:draw()

  elseif event.type == 'learn' then
    UI:setPage('learn')

  elseif event.type == 'craft' or event.type == 'grid_select' then
    local item = self.grid:getSelected()
    if Craft.findRecipe(item) or true then -- or item.is_craftable then
      UI:setPage('craft', self.grid:getSelected())
    else
      self.notification:error('No recipe defined')
    end

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then
      local key = Milo:uniqueKey(item)

      if context.userRecipes[key] then
        context.userRecipes[key] = nil
        Util.writeTable(Milo.RECIPES_FILE, context.userRecipes)
        Craft.loadRecipes()
      end

      if context.resources[key] then
        context.resources[key] = nil
        Milo:saveResources()
      end

      self.notification:info('Forgot: ' .. item.name)
      self:refresh()
      self.grid:draw()
    end

  elseif event.type == 'text_change' then
    self.filter = event.text
    if #self.filter == 0 then
      self.filter = nil
    end
    self:applyFilter()
    self.grid:draw()
    self.statusBar.filter:focus()

  else
    UI.Page.eventHandler(self, event)
  end
  return true
end

function listingPage:enable()
  self:refresh()
  self:setFocus(self.statusBar.filter)
  UI.Page.enable(self)
end

function listingPage:refresh()
  self.allItems = Milo:listItems()
  Milo:mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter, self.displayMode)
  self.grid:setValues(t)
end

UI:addPage('listing', listingPage)
