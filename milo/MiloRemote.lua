_G.requireInjector(_ENV)

local Socket = require('socket')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local socket

local options = {
  user   = { arg = 'u', type = 'string',
             desc = 'User name associated with bound manipulator' },
  server = { arg = 's', type = 'number',
             desc = 'ID of Milo server' },
  help   = { arg = 'h', type = 'flag', value = false,
             desc = 'Displays the options' },
}

local args = { ... }
if not Util.getOptions(options, args) then
  print()
  error('Invalid arguments')
end

if not options.user.value or not options.server.value then
  Util.showOptions(options)
  print()
  error('Invalid arguments')
end

local page = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Craft',   event = 'craft'   },
      { text = 'Refresh', event = 'refresh', x = -9 },
    },
  },
  grid = UI.Grid {
    y = 2, ey = -2,
    columns = {
      { heading = ' Qty', key = 'count'       , width = 4, justify = 'right' },
      { heading = 'Name', key = 'displayName' },
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
    [ 'control-r' ] = 'refresh',
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

function page:sendRequest(data)
  local msg

  for _ = 1, 2 do
    if not socket or not socket.connected then
      socket, msg = Socket.connect(options.server.value, 4242)
      if socket then
        socket:write(options.user.value)
      end
    end
    if socket then
      if socket:write(data) then
        local response = socket:read(2)
        if response then
          return response
        end
      end
      socket:close()
    end
  end
  self.notification:error(msg or 'Failed to connect')
end

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
  row.count = row.count > 0 and Util.toBytes(row.count) or ''
  if row.low then
    row.low = Util.toBytes(row.low)
  end
  if row.limit then
    row.limit = Util.toBytes(row.limit)
  end
  return row
end

function page:eventHandler(event)
  if event.type == 'quit' then
    UI:exitPullEvents()

  elseif event.type == 'eject' then
    local item = self.grid:getSelected()
    if item then
      local items = self:sendRequest({ request = 'transfer', item = item, count = 1 })
      if items then
        self.items = items
        self:applyFilter()
        self.grid:draw()
      end
    end

  elseif event.type == 'eject_stack' then
    local item = self.grid:getSelected()
    if item then
      local items = self:sendRequest({ request = 'transfer', item = item, count = 64 })
      if items then
        self.items = items
        self:applyFilter()
        self.grid:draw()
      end
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

function page:enable()
  self:refresh()
  self:setFocus(self.statusBar.filter)
  UI.Page.enable(self)
end

function page:refresh()
  local items = self:sendRequest({ request = 'list' })

  if items then
    self.items = items
    self:applyFilter()
  end
end

function page:applyFilter()
  local t = filterItems(self.items, self.filter, self.displayMode)
  self.grid:setValues(t)
end

UI:setPage(page)
UI:pullEvents()

if socket then
  socket:close()
end
