_G.requireInjector(_ENV)

local Config = require('config')
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

local config = Config.load('miloRemote', { displayMode = 0 })

local depositMode = {
  [ true ]  = { text = '\25',  textColor = colors.black, help = 'Deposit enabled' },
  [ false ] = { text = '\215', textColor = colors.red,  help = 'Deposit disabled' },
}

local displayModes = {
  [0] = { text = 'A', help = 'Showing all items' },
  [1] = { text = 'I', help = 'Showing inventory items' },
  [2] = { text = 'C', help = 'Showing craftable items' },
}

local page = UI.Page {
  menuBar = UI.MenuBar {
    y = 1, height = 1,
    buttons = {
      {
        name = 'depositToggle',
        text = '\215',
        x = -15,
        event = 'toggle_deposit'
      },
      {
        text = 'Refresh',
        x = -12,
        event = 'refresh'
      },
      {
        text = '\206',
        x = -3,
        dropdown = {
          { text = 'Setup', event = 'setup' },
          UI.MenuBar.spacer,
          {
            text = 'Rescan storage',
            event = 'rescan',
            help = 'Rescan all inventories'
          },
        },
      },
    },
    infoBar = UI.StatusBar {
      x = 1, ex = -16,
      backgroundColor = colors.lightGray,
    },
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
      help = 'Request amount',
    },
    display = UI.Button {
      x = -3,
      event = 'toggle_display',
      text = displayModes[config.displayMode].text,
      help = displayModes[config.displayMode].help,
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
  setup = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = 'Remote Setup',
    },
    form = UI.Form {
      x = 2, ex = -2, y = 2, ey = -1,
      values = config,
      [1] = UI.TextEntry {
        formLabel = 'Server', formKey = 'server',
        help = 'ID for the server',
        shadowText = 'Milo server ID',
        limit = 6,
        validate = 'numeric',
        required = true,
      },
      [2] = UI.TextEntry {
        formLabel = 'User Name', formKey = 'user',
        help = 'User name for bound manipulator',
        shadowText = 'User name',
        limit = 50,
        required = true,
      },
      [3] = UI.TextEntry {
        formLabel = 'Return Slot', formKey = 'slot',
        help = 'Use a slot for sending to storage',
        shadowText = 'Inventory slot #',
        limit = 5,
        validate = 'numeric',
        required = false,
      },
      [4] = UI.Checkbox {
        formLabel = 'Shield Slot', formKey = 'useShield',
        help = 'Or, use the shield slot for sending'
      },
      info = UI.TextArea {
        x = 1, ex = -1, y = 7, ey = -3,
        textColor = colors.yellow,
        marginLeft = 0,
        marginRight = 0,
        value = [[The Milo turtle must connect to a manipulator with a ]] ..
                [[bound introspection module. The neural interface must ]] ..
                [[also have an introspection module.]],
      },
    },
    statusBar = UI.StatusBar {
      backgroundColor = colors.cyan,
    },
  },
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
  self.menuBar.infoBar:setStatus(status)
  self:sync()
end

function page:sendRequest(data)
  local response

  if not config.server then
    self:setStatus('Invalid configuration')
    Event.onTimeout(2, function()
      self:setStatus('')
    end)
    return
  end

  sync(self, function()
    local msg
    for _ = 1, 2 do
      if not socket or not socket.connected then
        self:setStatus('connecting ...')
        socket, msg = Socket.connect(config.server, 4242)
        if socket then
          socket:write(config.user)
          local r = socket:read(2)
          if r and not r.msg then
            self:setStatus('connected ...')
          else
            msg = r and r.msg or 'Timed out'
            socket:close()
            socket = nil
            break
          end
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
  if response then
    item.count = response.current - response.count
    self.grid:draw()
    if response.craft > 0 then
      self:setStatus(response.craft .. ' crafting ...')
    elseif response.craft + response.count < response.requested then
      self:setStatus((response.craft + response.count) .. ' available ...')
    end
  end
end

function page.setup:eventHandler(event)
  if event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
  end
  return UI.SlideOut.eventHandler(self, event)
end

function page:eventHandler(event)
  if event.type == 'quit' then
    UI:exitPullEvents()

  elseif event.type == 'setup' then
    self.setup.form:setValues(config)
    self.setup:show()

  elseif event.type == 'toggle_deposit' then
    config.deposit = not config.deposit
    Util.merge(self.menuBar.depositToggle, depositMode[config.deposit])
    self.menuBar:draw()
    self:setStatus(depositMode[config.deposit].help)
    Config.update('miloRemote', config)

  elseif event.type == 'form_complete' then
    Config.update('miloRemote', config)
    self.setup:hide()
    self:refresh('list')
    self.grid:draw()
    self:setFocus(self.statusBar.filter)

  elseif event.type == 'form_cancel' then
    self.setup:hide()
    self:setFocus(self.statusBar.filter)

  elseif event.type == 'focus_change' then
    self.menuBar.infoBar:setStatus(event.focused.help)

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

  elseif event.type == 'rescan' then
    self:setFocus(self.statusBar.filter)
    self:setStatus('rescanning ...')
    self:refresh('scan')
    self.grid:draw()

  elseif event.type == 'refresh' then
    self:setFocus(self.statusBar.filter)
    self:setStatus('updating ...')
    self:refresh('list')
    self.grid:draw()

  elseif event.type == 'toggle_display' then
    config.displayMode = (config.displayMode + 1) % 3
    Util.merge(event.button, displayModes[config.displayMode])
    event.button:draw()
    self:applyFilter()
    self:setStatus(event.button.help)
    self.grid:draw()
    Config.update('miloRemote', config)

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
  Util.merge(self.menuBar.depositToggle, depositMode[config.deposit])
  UI.Page.enable(self)
  if not config.server then
    self.setup:show()
  end
  Event.onTimeout(.1, function()
    self:refresh('list')
    self.grid:draw()
    self:sync()
  end)
end

function page:refresh(requestType)
  local items = self:sendRequest({ request = requestType })

  if items then
    self.items = items
    self:applyFilter()
  end
end

function page:applyFilter()
  local t = filterItems(self.items, self.filter, config.displayMode)
  self.grid:setValues(t)
end

Event.addRoutine(function()
  local sleepTime = 1.5
  while true do
    os.sleep(sleepTime)
    if config.deposit then
      local neural = device.neuralInterface
      local inv = config.useShield and 'getEquipment' or 'getInventory'
      if not neural or not neural[inv] then
        _G._debug('missing Introspection module')
      elseif config.server and (config.useShield or config.slot) then
        local method = neural[inv]
        local item = method and method().getItemMeta(config.useShield and SHIELD_SLOT or config.slot)
        if item then
          local slotNo = config.useShield and 'shield' or config.slot
          local response = page:sendRequest({
            request = 'deposit',
            slot = slotNo,
            count = item.count,
            key = table.concat({ item.name, item.damage, item.nbtHash }, ':')
          })
          if response then
            local ritem = page.items[response.key]
            if ritem then
              ritem.count = response.current + item.count
            end
            page.grid:draw()
            page:sync()
            sleepTime = math.max(sleepTime - .25, .25)
          end
        else
          sleepTime = math.min(sleepTime + .25, 1.5)
        end
      end
    end
  end
end)

UI:setPage(page)
UI:pullEvents()

if socket then
  socket:close()
end
