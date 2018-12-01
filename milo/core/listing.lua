local Craft  = require('craft2')
local Event  = require('event')
local Milo   = require('milo')
local Sound  = require('sound')
local UI     = require('ui')
local Util   = require('util')

local colors      = _G.colors
local context     = Milo:getContext()
local displayMode = Milo:getState('displayMode') or 0
local string      = _G.string

local displayModes = {
  [0] = { text = 'A', help = 'Showing all items' },
  [1] = { text = 'I', help = 'Showing inventory items' },
}

local page = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Learn',   event = 'learn'   },
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
    sortColumn = Milo:getState('sortColumn') or 'count',
    inverseSort = Milo:getState('inverseSort'),
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
  throttle = UI.Throttle {
    textColor = colors.yellow,
    borderColor = colors.gray,
  },
  accelerators = {
    r = 'refresh',
    [ 'control-r' ] = 'refresh',

    [ 'control-e' ] = 'eject',
    [ 'control-s' ] = 'eject_stack',
    [ 'control-a' ] = 'eject_all',

    [ 'control-m' ] = 'network',

    q = 'quit',
  },
  allItems = { }
}

function page.statusBar:draw()
  return UI.Window.draw(self)
end

function page.grid:getRowTextColor(row, selected)
  if row.is_craftable then
    return colors.yellow
  end
  if row.has_recipe then
    return colors.cyan
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function page.grid:getDisplayValues(row)
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

function page.grid:sortCompare(a, b)
  if self.sortColumn ~= 'displayName' then
    if a[self.sortColumn] == b[self.sortColumn] then
      if self.inverseSort then
        return a.displayName > b.displayName
      end
      return a.displayName < b.displayName
    end
    if a[self.sortColumn] == 0 then
      return self.inverseSort
    end
    if b[self.sortColumn] == 0 then
      return not self.inverseSort
    end
    return a[self.sortColumn] < b[self.sortColumn]
  end
  return UI.Grid.sortCompare(self, a, b)
end

function page.grid:eventHandler(event)
  if event.type == 'grid_sort' then
    Milo:setState('sortColumn', event.sortColumn)
    Milo:setState('inverseSort', event.inverseSort)
  end
  return UI.Grid.eventHandler(self, event)
end

function page:eject(amount)
  local item = self.grid:getSelected()
  if item and amount then
    -- get most up-to-date item
    if item then
      if amount == 'stack' then
        amount = item.maxCount or 64
      elseif amount == 'all' then
        item = Milo:getItem(Milo:listItems(), item)
        amount = item.count
      end

      if amount > 0 then
        item = Util.shallowCopy(item)
        self.grid.values[self.grid.sorted[self.grid.index]] = item
        local request = Milo:craftAndEject(item, amount)
        item.count = request.current - request.count
        if request.count + request.craft > 0 then
          self.grid:draw()
          Sound.play('ui.button.click', .3)
          return true
        end
      end
    end
  end
  Sound.play('entity.villager.no')
end

function page:eventHandler(event)
  if event.type == 'quit' then
    UI:exitPullEvents()

  elseif event.type == 'eject' or event.type == 'grid_select' then
    self:eject(1)

  elseif event.type == 'eject_stack' then
    self:eject('stack')

  elseif event.type == 'eject_all' then
    self:eject('all')

  elseif event.type == 'eject_specified' then
    if self:eject(tonumber(self.statusBar.amount.value)) then
      self.statusBar.amount:reset()
      self:setFocus(self.statusBar.filter)
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
    displayMode = (displayMode + 1) % 2
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
        Sound.play('entity.villager.no')
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

function page:enable(args)
  local function updateStatus()
    self.statusBar.storageStatus.value =
      context.storage:isOnline() and '' or 'offline'
    self.statusBar.storageStatus.textColor =
      context.storage:isOnline() and colors.lime or colors.red
  end
  updateStatus()

  Event.onTimeout(0, function()
    self:refresh()
    self:draw()
    self:sync()

    self.timer = Event.onInterval(3, function()
      for _,v in pairs(self.grid.values) do
        local c = context.storage.cache[v.key]
        v.count = c and c.count or 0
      end
      self.grid:draw()
      self:sync()
    end)

    self.handler = Event.on({ 'storage_offline', 'storage_online' }, function()
      updateStatus()
      self.statusBar.storageStatus:draw()
      self:sync()
    end)
  end)

  if args and args.filter then
    self.filter = args.filter
    self.statusBar.filter.value = args.filter
  end

  if args and args.message then
    self.notification:success(args.message)
  end

  self:setFocus(self.statusBar.filter)
  UI.Page.enable(self)
end

function page:disable()
  Event.off(self.timer)
  Event.off(self.handler)
  UI.Page.disable(self)
end

function page:refresh(force)
  local throttle = function() self.throttle:update() end

  self.throttle:enable()
  self.allItems = Milo:mergeResources(Milo:listItems(force, throttle))
  self:applyFilter()
  self.throttle:disable()
end

function page:applyFilter()
  local function filterItems(t, filter)
    if filter or displayMode > 0 then
      local r = { }
      if filter then
        filter = filter:lower()
      end
      for _,v in pairs(t) do
        if not filter or string.find(v.lname, filter, 1, true) then
          if filter or --displayMode == 0 or
            displayMode == 1 and v.count > 0 then
            table.insert(r, v)
          end
        end
      end
      return r
    end
    return t
  end

  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

UI:addPage('listing', page)
