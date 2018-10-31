_G.requireInjector(_ENV)

local Event  = require('event')
local Socket = require('socket')
local sync   = require('sync').sync
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device
local os     = _G.os
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
    values = { },
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
  },
  displayMode = 0,
  items = { },
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

  sync(self, function()
    local msg
    for _ = 1, 2 do
      if not socket or not socket.connected then
        self:setStatus('connecting ...')
        socket, msg = Socket.connect(options.server.value, 4242)
        if socket then
          self:setStatus('connected ...')
          socket:write(options.user.value)
        end
      end
      if socket then
        if socket:write(data) then
          response = socket:read(2)
          if response then
            if response.msg then
              self:setStatus(response.msg)
              response = nil
            end
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
    Event.onTimeout(2, function()
      self:setStatus('')
    end)
  end)

  return response
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
  return row
end

function page:transfer(item, count)
  local response = self:sendRequest({ request = 'transfer', item = item, count = count })
  debug(response)
  if response then
    item.count = response.current - response.transferred
    self.grid:draw()
    if response.craft > 0 then
      self:setStatus(response.craft .. ' crafting ...')
    elseif response.craft + response.available < response.requested then
      self:setStatus((response.craft + response.available) .. ' available ...')
    end
  end
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
      self:transfer(item, 1)
    end

  elseif event.type == 'eject_stack' then
    local item = self.grid:getSelected()
    if item then
      self:setStatus('requesting stack ...')
      self:transfer(item, 'stack')
    end

  elseif event.type == 'eject_all' then
    local item = self.grid:getSelected()
    if item then
      self:setStatus('requesting all ...')
      self:transfer(item, 'all')
    end

  elseif event.type == 'eject_specified' then
    local item = self.grid:getSelected()
    local count = tonumber(self.statusBar.amount.value)
    if item and count then
      self.statusBar.amount:reset()
      self:setFocus(self.statusBar.filter)
      self:setStatus('requesting ' .. count .. ' ...')
      self:transfer(item, count)
    else
      self:setStatus('nope ...')
    end

  elseif event.type == 'refresh' then
    self:setFocus(self.statusBar.filter)
    self:setStatus('updating ...')
    self:refresh()
    self.grid:draw()

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
  self:setFocus(self.statusBar.filter)
  UI.Page.enable(self)
  Event.onTimeout(.1, function()
    self:refresh()
    self.grid:draw()
    self:sync()
  end)
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

if options.slot.value or options.shield.value then
  local inv = 'getInventory'
  local slotNo = options.slot.value
  local slotValue = options.slot.value

  if options.shield.value then
    slotNo = SHIELD_SLOT
    slotValue = 'shield'
    inv = 'getEquipment'
  end

  Event.addRoutine(function()
    while true do
      os.sleep(1.5)
      local neural = device.neuralInterface
      if not neural or not neural[inv] then
        _debug('missing Introspection module')
      end

      local method = neural and neural[inv]
      local item = method and method().getItemMeta(slotNo)
      if item then
        _debug('depositing')
        local response = page:sendRequest({
          request = 'deposit',
          slot = slotValue,
          key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
        })
        if response then
          local ritem = page.items[response.key]
          if ritem then
            ritem.count = response.current
          end
          page.grid:draw()
          page:sync()
        end
      end
    end
  end)
end

UI:setPage(page)
UI:pullEvents()

if socket then
  socket:close()
end
