local Ansi   = require('ansi')
local Craft  = require('craft2')
local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device

local context = Milo:getContext()

local itemPage = UI.Page {
  titleBar = UI.TitleBar {
    title = 'Limit Resource',
    previousPage = true,
    event = 'form_cancel',
  },
  form = UI.Form {
    x = 1, y = 2, height = 10, ex = -1,
    [1] = UI.TextEntry {
      formLabel = 'Name', formKey = 'displayName', help = 'Override display name',
      shadowText = 'Display name',
      required = true,
      limit = 120,
    },
    [2] = UI.TextEntry {
      width = 7,
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min',
      validate = 'numeric',
    },
    [3] = UI.TextEntry {
      width = 7,
      formLabel = 'Max', formKey = 'limit', help = 'Send to trash if above max',
      validate = 'numeric',
    },
    [4] = UI.Checkbox {
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      help = 'Ignore damage of item',
    },
    [5] = UI.Checkbox {
      formLabel = 'Ignore NBT', formKey = 'ignoreNbtHash',
      help = 'Ignore NBT of item',
    },
    machineButton = UI.Button {
      x = 2, y = -2, width = 10,
      formLabel = 'Machine',
      event = 'select_machine',
      text = 'Configure',
    },
    infoButton = UI.Button {
      x = 2, y = -2,
      event = 'show_info',
      text = 'Info',
    },
    resetButton = UI.Button {
      x = 9, y = -2,
      event = 'reset',
      text = 'Reset',
      help = 'Clear recipe and all settings',
    },
  },
  rsControl = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = "Redstone Control",
    },
    form = UI.Form {
      y = 2,
      [1] = UI.Chooser {
        width = 7,
        formLabel = 'RS Control', formKey = 'rsControl',
        nochoice = 'No',
        choices = {
          { name = 'Yes', value = true },
          { name = 'No', value = false },
        },
        help = 'Control via redstone'
      },
      [2] = UI.Chooser {
        width = 25,
        formLabel = 'RS Device', formKey = 'rsDevice',
        --choices = devices,
        help = 'Redstone Device'
      },
      [3] = UI.Chooser {
        width = 10,
        formLabel = 'RS Side', formKey = 'rsSide',
        --nochoice = 'No',
        choices = {
          { name = 'up', value = 'up' },
          { name = 'down', value = 'down' },
          { name = 'east', value = 'east' },
          { name = 'north', value = 'north' },
          { name = 'west', value = 'west' },
          { name = 'south', value = 'south' },
        },
        help = 'Output side'
      },
    },
  },
  machines = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = 'Select Machine',
      event = 'cancel_machine',
    },
    grid = UI.ScrollingGrid {
      y = 2, ey = -5,
      disableHeader = true,
      values = context.config.nodes,
      columns = {
        { heading = 'Name', key = 'displayName'},
      },
      sortColumn = 'displayName',
    },
    button1 = UI.Button {
      x = -14, y = -3,
      text = 'Ok', event = 'set_machine',
    },
    button2 = UI.Button {
      x = -9, y = -3,
      text = 'Cancel', event = 'cancel_machine',
    },
    statusBar = UI.StatusBar { values = 'Enter or double click to select' },
  },
  info = UI.SlideOut {
    titleBar = UI.TitleBar {
      title = "Information",
    },
    textArea = UI.TextArea {
      x = 2, ex = -2, y = 3, ey = -4,
      backgroundColor = colors.black,
    },
    cancel = UI.Button {
      ex = -2, y = -2, width = 6,
      text = 'Okay',
      event = 'hide_info',
    },
  },
  statusBar = UI.StatusBar { },
  notification = UI.Notification { },
}

function itemPage:enable(item)
  self.origItem = item
  self.item = Util.shallowCopy(item)
  self.res = item.resource or { }
  self.res.displayName = self.item.displayName
  self.form:setValues(self.res)

  self.titleBar.title = item.displayName or item.name
  self.form.machineButton.inactive = not Craft.machineLookup[self.item.key]

  UI.Page.enable(self)
  self:focusFirst()
end

function itemPage.machines.grid:isRowValid(_, value)
  local ignores = Util.transpose({ 'storage', 'ignore', 'hidden' })
  if not ignores[value.mtype] then
    local node = context.storage.nodes[value.name]
_debug(node)
    return node and node.adapter and node.adapter.online and node.adapter.pushItems
  end
end

function itemPage.machines.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.displayName = row.displayName or row.name
  return row
end

  function itemPage.machines.grid:getRowTextColor(row, selected)
    if row.name == Craft.machineLookup[itemPage.item.key] then
      return colors.yellow
    end
    return UI.Grid:getRowTextColor(row, selected)
  end

function itemPage.rsControl:enable()
  local devices = self.form[2].choices
  Util.clear(devices)
  for _,dev in pairs(device) do
    if dev.setOutput then
      table.insert(devices, { name = dev.name, value = dev.name })
    end
  end

  if Util.size(devices) == 0 then
    table.insert(devices, { name = 'None found', values = '' })
  end

  UI.SlideOut.enable(self)
end

function itemPage.rsControl:eventHandler(event)
  if event.type == 'form_cancel' then
    self:hide()
  elseif event.type == 'form_complete' then
    self:hide()
  else
    return UI.SlideOut.eventHandler(self, event)
  end
  return true
end

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'show_rs' then
    self.rsControl:show()

  elseif event.type == 'select_machine' then
    self.machines.grid:update()
    self.machines.grid:setIndex(1)
    self.machines:show()

  elseif event.type == 'reset' then
    if context.userRecipes[self.item.key] then
      context.userRecipes[self.item.key] = nil
      Util.writeTable(Craft.USER_RECIPES, context.userRecipes)
      Craft.loadRecipes()
    end

    if context.resources[self.item.key] then
      context.resources[self.item.key] = nil
      Milo:saveResources()
    end

    if Craft.machineLookup[self.item.key] then
      Craft.machineLookup[self.item.key] = nil
      Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)
    end

    UI:setPreviousPage()

  elseif event.type == 'grid_select' then
    Craft.machineLookup[self.item.key] = event.selected.name
    self.machines.grid:draw()

  elseif event.type == 'set_machine' then
    local machine = self.machines.grid:getSelected()
    if machine then
      Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)
    end
    self.machines:hide()

  elseif event.type == 'cancel_machine' then
    self.machines:hide()

  elseif event.type == 'show_info' then
    local value =
      string.format('%s%s%s\n%s\n',
        Ansi.orange, self.item.displayName, Ansi.reset,
        self.item.name)

    if self.item.nbtHash then
      value = value .. self.item.nbtHash .. '\n'
    end

    value = value .. string.format('\n%sDamage:%s %s',
      Ansi.yellow, Ansi.reset, self.item.damage)

    if self.item.maxDamage and self.item.maxDamage > 0 then
      value = value .. string.format(' (max: %s)', self.item.maxDamage)
    end

    if self.item.maxCount then
      value = value .. string.format('\n%sStack Size: %s%s',
        Ansi.yellow, Ansi.reset, self.item.maxCount)
    end

    self.info.textArea.value = value
    self.info:show()

  elseif event.type == 'hide_info' then
    self.info:hide()

  elseif event.type == 'form_invalid' then
    self.notification:error(event.message)

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local item = self.item

    if self.form:save() then
      if self.res.displayName ~= self.origItem.displayName then
        self.origItem.displayName = self.res.displayName
        itemDB:add(self.origItem)
        itemDB:flush()
      end
      self.res.displayName = nil
      Util.prune(self.res, function(v)
        if type(v) == 'boolean' then
          return v
        elseif type(v) == 'string' then
          return #v > 0
        end
        return true
      end)

      local newKey = {
        name = item.name,
        damage = self.res.ignoreDamage and 0 or item.damage,
        nbtHash = not self.res.ignoreNbtHash and item.nbtHash or nil,
      }

      for k,v in pairs(context.resources) do
        if v == self.res then
          context.resources[k] = nil
          break
        end
      end

      if not Util.empty(self.res) then
        context.resources[Milo:uniqueKey(newKey)] = self.res
      end

      Milo:saveResources()
      UI:setPreviousPage()
    end
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

UI:addPage('item', itemPage)
