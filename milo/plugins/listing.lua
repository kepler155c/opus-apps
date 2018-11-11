local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Event  = require('event')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local context = Milo:getContext()

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
      --{ text = 'Forget',  event = 'forget'   },
      { text = 'Craft',   event = 'craft'   },
      { text = 'Edit',    event = 'details' },
      { text = 'Network', event = 'network' },
      { text = 'Refresh', event = 'refresh', x = -9 },
    },
  },
  grid = UI.Grid {
    y = 2, ey = -2,
    columns = {
      { heading = ' Qty', key = 'count'        , width = 4, justify = 'right' },
      { heading = 'Name', key = 'displayName' },
      { heading = 'Min',  key = 'low'          , width = 4 },
      { heading = 'Max',  key = 'limit'        , width = 4 },
    },
    sortColumn = 'displayName',
  },
  statusBar = UI.StatusBar {
    filter = UI.TextEntry {
      x = 1, ex = -17,
      limit = 50,
      shadowText = 'filter',
      shadowTextColor = colors.gray,
      backgroundColor = colors.cyan,
      backgroundFocusColor = colors.cyan,
      accelerators = {
        [ 'enter' ] = 'craft',
      },
    },
    storageStatus = UI.Text {
      x = -16, ex = -9,
      textColor = colors.lime,
      backgroundColor = colors.cyan,
      value = '',
    },
    amount = UI.TextEntry {
      x = -8, ex = -4,
      limit = 3,
      shadowText = '1',
      shadowTextColor = colors.gray,
      backgroundColor = colors.black,
      backgroundFocusColor = colors.black,
      accelerators = {
        [ 'enter' ] = 'eject_specified',
      },
      help = 'Specify an amount to send',
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
    [ 'control-r' ] = 'refresh',

    [ 'control-e' ] = 'eject',
    [ 'control-s' ] = 'eject_stack',
    [ 'control-a' ] = 'eject_all',

    [ 'control-m' ] = 'network',

    q = 'quit',
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
  row.count = row.count > 0 and Util.toBytes(row.count)
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

  elseif event.type == 'eject' or event.type == 'grid_select' then
    local item = self.grid:getSelected()
    if item then
      item.count = Milo:craftAndEject(item, 1)
      self.grid:draw()
    end

  elseif event.type == 'eject_stack' then
    local item = self.grid:getSelected()
    if item then
      item.count = Milo:craftAndEject(item, itemDB:getMaxCount(item))
      self.grid:draw()
    end

  elseif event.type == 'eject_all' then
    local item = self.grid:getSelected()
    if item then
      local updated = Milo:getItem(Milo:listItems(), item)
      if updated then
        Milo:craftAndEject(item, updated.count)
      end
    end

  elseif event.type == 'eject_specified' then
    local item = self.grid:getSelected()
    local count = tonumber(self.statusBar.amount.value)
    if item and count then
      self.statusBar.amount:reset()
      self:setFocus(self.statusBar.filter)
      Milo:craftAndEject(item, count)
    end

  elseif event.type == 'network' then
    UI:setPage('network')

  elseif event.type == 'details' or event.type == 'grid_select_right' then
    local item = self.grid:getSelected()
    if item then
      UI:setPage('item', item)
    end

  elseif event.type == 'refresh' then
    self:refresh(true)
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

  elseif event.type == 'craft' then
    local item = self.grid:getSelected()
    if Craft.findRecipe(item) or true then -- or item.is_craftable then
      UI:setPage('craft', self.grid:getSelected())
    else
      self.notification:error('No recipe defined')
    end

  elseif event.type == 'text_change' and event.element == self.statusBar.filter then
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
  self.timer = Event.onInterval(3, function()
    for _,v in pairs(self.allItems) do
      local c = context.storage.cache[v.key]
      v.count = c and c.count or 0
    end
    self.grid:draw()
    self:sync()
  end)
  UI.Page.enable(self)
end

function listingPage:disable()
  Event.off(self.timer)
  UI.Page.disable(self)
end

function listingPage:refresh(force)
  self.allItems = Milo:mergeResources(Milo:listItems(force))
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter, self.displayMode)
  self.grid:setValues(t)
end

Event.on({ 'storage_offline', 'storage_online' }, function(e, isOnline)
  -- TODO: Fix button
  listingPage.statusBar.storageStatus.value =
    isOnline and '' or 'offline'
  listingPage.statusBar.storageStatus.textColor =
    isOnline and colors.lime or colors.red
  listingPage.statusBar.storageStatus:draw()
  listingPage:sync()
end)

UI:addPage('listing', listingPage)
