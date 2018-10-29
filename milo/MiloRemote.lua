_G.requireInjector(_ENV)

local Event  = require('event')
local Socket = require('socket')
local sync   = require('sync')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device
local socket

local SHIELD_SLOT = 2

local options = {
  user   = { arg = 'u', type = 'string',
             desc = 'User name associated with bound manipulator' },
  slot   = { arg = 's', type = 'number',
             desc = 'Optional inventory slot to use to transfer to milo' },
  shield = { arg = 'e', type = 'flag',
             desc = 'Use shield slot to use to transfer to milo' },
  server = { arg = 'm', type = 'number',
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

if (options.slot.value or options.shield.value) and
   not (device.neuralInterface and device.neuralInterface.getInventory) then
  error('Introspection module is required for transferring items')
end

local page = UI.Page {
  dummy = UI.Window {
     x = 1, ex = -10, y = 1, height = 1,
    infoBar = UI.StatusBar {
      backgroundColor = colors.lightGray,
    },
  },
  refresh = UI.Button {
    y = 1, x = -9,
    event = 'refresh',
    text = 'Refresh',
  },
  grid = UI.Grid {
    y = 2, ey = -2,
    columns = {
      { heading = ' Qty', key = 'count'       , width = 4, justify = 'right' },
      { heading = 'Name', key = 'displayName' },
    },
    sortColumn = 'displayName',
    help = '^(s)tack, ^(a)ll'
  },
  statusBar = UI.Window {
    y = -1,
    filter = UI.TextEntry {
      x = 1, ex = -9,
      limit = 50,
      shadowText = 'filter',
      backgroundColor = colors.cyan,
      backgroundFocusColor = colors.cyan,
      accelerators = {
        [ 'enter' ] = 'eject',
      },
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
      help = 'Toggle display mode',
    },
  },
  accelerators = {
    r = 'refresh',
    [ 'control-r' ] = 'refresh',
    [ 'control-e' ] = 'eject',
    [ 'control-s' ] = 'eject_stack',
    [ 'control-a' ] = 'eject_all',

    q = 'quit',

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

function page:setStatus(status)
  self.dummy.infoBar:setStatus(status)
  self:sync()
end

function page:sendRequest(data)
  local response

debug(data)
  sync(self, function()
    self:sync()
    local msg
    for _ = 1, 2 do
      if not socket or not socket.connected then
        self:setStatus('connecting ...')
        socket, msg = Socket.connect(options.server.value, 4242)
        if socket then
          socket:write(options.user.value)
        end
      end
      if socket then
        if socket:write(data) then
          response = socket:read(2)
          if response then
            Event.onTimeout(2, function()
              self:setStatus('')
            end)
            return
          end
        end
        socket:close()
      end
    end
    self:setStatus(msg or 'Failed to connect')
  end)
debug('got response')
  return response
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

  elseif event.type == 'focus_change' then
    self.dummy.infoBar:setStatus(event.focused.help)

  elseif event.type == 'eject' or event.type == 'grid_select' then
    local item = self.grid:getSelected()
    if item then
      self:setStatus('requesting 1 ...')
      local response = self:sendRequest({ request = 'transfer', item = item, count = 1 })
      item.count = response.count
      self.grid:draw()
    end

  elseif event.type == 'eject_stack' then
    local item = self.grid:getSelected()
    if item then
      self:setStatus('requesting stack ...')
      local response = self:sendRequest({ request = 'transfer', item = item, count = 64 })
      item.count = response.count
      self.grid:draw()
    end

  elseif event.type == 'eject_all' then
    local item = self.grid:getSelected()
    if item then
      self:setStatus('requesting all ...')
      local response = self:sendRequest({ request = 'transfer', item = item, count = item.count })
      item.count = response.count
      self.grid:draw()
    end

  elseif event.type == 'eject_specified' then
    local item = self.grid:getSelected()
    local count = tonumber(self.statusBar.amount.value)
    if item and count then
      self.statusBar.amount:reset()
      self:setFocus(self.statusBar.filter)
      self:setStatus('requesting ' .. count .. ' ...')
      local response = self:sendRequest({ request = 'transfer', item = item, count = count })
      item.count = response.count
      self.grid:draw()
    else
      self:setStatus('nope ...')
    end

  elseif event.type == 'refresh' then
    self:setStatus('updating ...')
    self:refresh()
    self.grid:draw()
    self:setFocus(self.statusBar.filter)

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

  elseif event.type == 'text_change' and event.element == self.statusBar.filter then
    self.filter = event.text
    if #self.filter == 0 then
      self.filter = nil
    end
    self:applyFilter()
    self.grid:draw()

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

debug(options.slot)
if options.slot.value then
  debug('Transfer items initialized')
  Event.addRoutine(function()
    while true do
      os.sleep(1.5)
      local neural = device.neuralInterface
      if neural and neural.getInventory then
        local item = neural.getInventory().getItem(options.slot.value)
        if item then
          debug('depositing')
          page:sendRequest({ request = 'deposit', slot = options.slot.value })
          -- local item =
          -- TODO: update count for this one item
          -- page.grid:draw() page:sync()
        end
      else
        debug('missing Introspection module')
      end
    end
  end)
end

if options.shield.value then
  debug('Transfer items initialized')
  Event.onInterval(2, function()
    local neural = device.neuralInterface
    if neural and neural.getEquipment then
      local item = neural.getEquipment().getItem(SHIELD_SLOT)
      if item then
        debug('depositing')
        page:sendRequest({ request = 'deposit', slot = 'shield' })
        -- local item =
        -- TODO: update count for this one item
        -- page.grid:draw() page:sync()
      end
    else
      debug('missing Introspection module')
    end
  end)
end

UI:setPage(page)
UI:pullEvents()

if socket then
  socket:close()
end
