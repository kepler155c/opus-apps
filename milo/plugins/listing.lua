local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Event  = require('event')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors      = _G.colors
local context     = Milo:getContext()
local displayMode = Milo:getState('displayMode') or 0

local displayModes = {
  [0] = { text = 'A', help = 'Showing all items' },
  [1] = { text = 'I', help = 'Showing inventory items' },
  [2] = { text = 'C', help = 'Showing craftable items' },
}

local function filterItems(t, filter)
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
      { text = 'Refresh', event = 'refresh', x = -12 },
      {
        text = '\206',
        x = -3,
        dropdown = {
          { text = 'Setup', event = 'network' },
          UI.MenuBar.spacer,
          {
            text = 'Rescan storage',
            event = 'rescan',
            help = 'Rescan all inventories'
          },
        },
      },
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
        [ 'enter' ] = 'eject',
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
      text = displayModes[displayMode].text,
      help = displayModes[displayMode].help,
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
    self:refresh()
    self.grid:draw()
    self:setFocus(self.statusBar.filter)

  elseif event.type == 'rescan' then
    self:refresh(true)
    self.grid:draw()
    self:setFocus(self.statusBar.filter)

  elseif event.type == 'toggle_display' then
    displayMode = (displayMode + 1) % 3
    Util.merge(event.button, displayModes[displayMode])
    event.button:draw()
    self:applyFilter()
    self.grid:draw()
    Milo:setState('displayMode', displayMode)

  elseif event.type == 'learn' then
    UI:setPage('learn')

  elseif event.type == 'craft' then
    local item = self.grid:getSelected()
    if item then
      if Craft.findRecipe(item) then -- or item.is_craftable then
        UI:setPage('craft', self.grid:getSelected())
      else
        self.notification:error('No recipe defined')
      end
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

  self.handler = Event.on({ 'storage_offline', 'storage_online' }, function(_, isOnline)
    self.statusBar.storageStatus.value =
      isOnline and '' or 'offline'
    self.statusBar.storageStatus.textColor =
      isOnline and colors.lime or colors.red
    self.statusBar.storageStatus:draw()
    self:sync()
  end)

  UI.Page.enable(self)
end

function listingPage:disable()
  Event.off(self.timer)
  Event.off(self.handler)
  UI.Page.disable(self)
end

function listingPage:refresh(force)
  self.allItems = Milo:mergeResources(Milo:listItems(force))
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

UI:addPage('listing', listingPage)
