local Config = require('config')
local Lora   = require('lora/lora')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors

local context = Lora:getContext()

local machinesPage = UI.Page {
  titleBar = UI.TitleBar {
    previousPage = true,
    title = 'Machines',
  },
  grid = UI.ScrollingGrid {
    y = 2, ey = -2,
    values = context.config.remoteDefaults,
    columns = {
      { heading = 'Name',     key = 'displayName' },
      { heading = 'Priority', key = 'priority', width = 5  },
      { heading = 'Type',     key = 'mtype',    width = 5  },
    },
    sortColumn = 'name',
  },
  detail = UI.SlideOut {
    backgroundColor = colors.cyan,
    form = UI.Form {
      x = 1, y = 2, ex = -1, ey = -2,
      [7] = UI.Text {
        x = 12, y = 1,
        width = 28,
      },
      [1] = UI.TextEntry {
        formLabel = 'Name', formKey = 'displayName', help = '...',
        limit = 64,
      },
      [2] = UI.Chooser {
        width = 15,
        formLabel = 'Type', formKey = 'mtype',
        nochoice = 'Storage',
        choices = {
          { name = 'Storage',     value = 'storage'  },
          { name = 'Trashcan',    value = 'trashcan' },
          { name = 'Input chest', value = 'input'    },
          { name = 'Ignore',      value = 'ignore'   },
        },
        help = 'Check if machine is empty before crafting'
      },
      [3] = UI.Chooser {
        width = 7,
        formLabel = 'Empty', formKey = 'empty',
        nochoice = 'No',
        choices = {
          { name = 'Yes', value = true },
          { name = 'No', value = false },
        },
        help = 'Check if machine is empty before crafting'
      },
      [4] = UI.TextEntry {
        formLabel = 'Priority', formKey = 'priority', help = '...',
        limit = 4,
      },
      [5] = UI.TextEntry {
        formLabel = 'Max Craft', formKey = 'maxCount', help = '...',
        limit = 4,
      },
      [6] = UI.TextEntry {
        formLabel = 'Lock to', formKey = 'lockWith', help = '...',
        width = 18,
        limit = 64,
      },
      [8] = UI.Button {
        x = -9, ey = -4,
        text = 'Detect', help = '...',
        limit = 64,
      },
    },
    statusBar = UI.StatusBar(),
  },
  statusBar = UI.StatusBar {
    values = 'Select Machine',
  },
  accelerators = {
    h = 'toggle_hidden',
  }
}

function machinesPage:enable()
  self.grid:update()
  UI.Page.enable(self)
end

function machinesPage.detail:eventHandler(event)
  if event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
  end
  return UI.SlideOut.eventHandler(self, event)
end

function machinesPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.displayName = row.displayName or row.name
  return row
end

function machinesPage.grid:getRowTextColor(row, selected)
  if row.mtype == 'ignore' then
    return colors.lightGray
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function machinesPage:eventHandler(event)
  if event.type == 'grid_select' then
    self.detail.form:setValues(event.selected)
    self.detail.form[7].value = event.selected.name
debug(event.selected)
    self.detail:show()

  elseif event.type == 'toggle_hidden' then
    local selected = self.grid:getSelected()
    if selected then
      selected.ignore = not selected.ignore
--      Util.writeTable(MACHINES_FILE, machines)
      self:draw()
    end

  elseif event.type == 'form_complete' then
    self.detail.form.values.empty = self.detail.form.values.empty == true or nil
    self.detail.form.values.ignore = self.detail.form.values.ignore == true or nil
    self.detail.form.values.priority = tonumber(self.detail.form.values.priority)
    self.detail.form.values.maxCount = tonumber(self.detail.form.values.maxCount)
    if #self.detail.form.values.displayName == 0 then
      self.detail.form.values.displayName = nil
    end
    if #self.detail.form.values.lockWith == 0 then
      self.detail.form.values.lockWith = nil
    end
    Config.update('inventoryManager', context.config)
    self.detail:hide()
    self.grid:update()

  elseif event.type == 'form_cancel' then
    self.detail:hide()

  else
    UI.Page.eventHandler(self, event)
  end
  return true
end

UI:addPage('machines', machinesPage)
