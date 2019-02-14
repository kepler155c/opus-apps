local Ansi       = require('ansi')
local Event      = require('event')
local Milo       = require('milo')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors
local context    = Milo:getContext()
local device     = _G.device
local os         = _G.os

--[[ Configuration Page ]]--
local template =
[[%sDisplays the amount of items entering or leaving storage.%s
Right-clicking on the activity monitor will reset the totals.]]

local wizardPage = UI.WizardPage {
  title = 'Status Monitor',
  index = 2,
  backgroundColor = colors.cyan,
  [1] = UI.TextArea {
    x = 2, ex = -2, y = 2, ey = 6,
    marginRight = 0,
    value = string.format(template, Ansi.yellow, Ansi.reset),
  },
  form = UI.Form {
    x = 2, ex = -2, y = 7, ey = -2,
    manualControls = true,
    [1] = UI.Chooser {
      width = 9,
      formLabel = 'Font Size', formKey = 'textScale',
      nochoice = 'Small',
      choices = {
        { name = 'Small', value = .5 },
        { name = 'Large', value = 1  },
      },
      help = 'Adjust text scaling',
    },
  },
}

function wizardPage:setNode(node)
  self.form:setValues(node)
end

function wizardPage:validate()
  return self.form:save()
end

function wizardPage:saveNode(node)
  os.queueEvent('monitor_resize', node.name)
end

function wizardPage:isValidType(node)
  local m = device[node.name]
  return m and m.type == 'monitor' and {
    name = 'Status Monitor',
    value = 'status',
    category = 'display',
    help = 'Display storage status'
  }
end

function wizardPage:isValidFor(node)
  return node.mtype == 'activity'
end

UI:getPage('nodeWizard').wizard:add({ statusMonitor = wizardPage })

--[[ Display ]]--
local function createPage(node)
  local monitor = UI.Device {
    device = node.adapter,
    textScale = node.textScale or .5,
  }

  function monitor:resize()
    self.textScale = node.textScale or .5
    UI.Device.resize(self)
  end

  local page = UI.Page {
    parent = monitor,
    tabs = UI.Tabs {
      [1] = UI.Tab {
        tabTitle = 'Overview',
        titleBar = UI.TitleBar {
          title = 'Overview',
        },
        textArea = UI.TextArea {
          y = 3,
        },
      },
      [2] = UI.Tab {
        tabTitle = 'Storage',
        titleBar = UI.TitleBar {
          title = 'Storage chest usage',
        },
        grid = UI.Grid {
          y = 2,
          columns = {
            { heading = 'Name', key = 'name' },
            { heading = 'Size', key = 'size', width = 5 },
            { heading = 'Used', key = 'used', width = 5 },
            { heading = 'Perc', key = 'perc', width = 5 },
          },
          sortColumn = 'name',
        },
      },
      [3] = UI.Tab {
        tabTitle = 'Offline',
        titleBar = UI.TitleBar {
          title = 'Offline Nodes',
        },
        grid = UI.ScrollingGrid {
          y = 2,
          columns = {
            { heading = 'Name', key = 'name' },
          },
          sortColumn = 'name',
        },
      }
    },
    timestamp = os.clock(),
  }

  local overviewTab = page.tabs[1]
  local usageTab = page.tabs[2]
  local stateTab = page.tabs[3]

  local function getStorageStats()
    local stats = { }
    for n in context.storage:filterActive('storage') do
      if n.adapter.size and n.adapter.list then
        pcall(function()
          if not n.adapter.__size then
            n.adapter.__size = n.adapter.size()
            n.adapter.__used = Util.size(n.adapter.list())
          end
          if n.adapter.__lastUpdate ~= n.adapter.lastUpdate then
            n.adapter.__used = Util.size(n.adapter.list())
            n.adapter.__lastUpdate = n.adapter.lastUpdate
          end
          table.insert(stats, {
            name = n.displayName or n.name,
            size = n.adapter.__size,
            used = n.adapter.__used,
            perc = math.floor(n.adapter.__used / n.adapter.__size * 100),
          })
        end)
      end
    end
    return stats
  end

  function stateTab:refresh()
    self.grid.values = { }
    for _, v in pairs(context.storage.nodes) do
      if v.mtype ~= 'hidden' then
        if not v.adapter or not v.adapter.online then
          table.insert(self.grid.values, {
            name = v.displayName or v.name
          })
        end
      end
    end
    self.grid:update()
  end

  function stateTab:enable()
    self:refresh()
    self.handle = Event.onInterval(5, function()
      self:refresh()
      self.grid:draw()
      self:sync()
    end)
    UI.Tab.enable(self)
  end

  function stateTab:disable()
    Event.off(self.handle)
  end

  function usageTab:refresh()
    self.grid:setValues(getStorageStats())
  end

  function usageTab:enable()
    self:refresh()
    self.handle = Event.onInterval(5, function()
      self:refresh()
      self.grid:draw()
      self:sync()
    end)
    UI.Tab.enable(self)
  end

  function usageTab:disable()
    Event.off(self.handle)
  end

  function usageTab.grid:getRowTextColor(row, selected)
    if row.lastCount and row.lastCount ~= row.count then
      return row.count > row.lastCount and colors.yellow or colors.lightGray
    end
    return UI.Grid:getRowTextColor(row, selected)
  end

  function overviewTab.textArea:draw()
    local stats = getStorageStats()
    local usedSlots, totalSlots, totalItems = 0, 0, 0
    local formatString = [[
Storage Usage : %d%%
Slots         : %d of %d used
Unique Items  : %d
Total Items   : %d
]]

    for _, v in pairs(stats) do
      usedSlots = usedSlots + v.used
      totalSlots = totalSlots + v.size
    end

    for _,v in pairs(context.storage.cache) do
      totalItems = totalItems + v.count
    end

    self.value = string.format(formatString,
      math.floor(usedSlots / totalSlots * 100),
      usedSlots, totalSlots,
      Util.size(context.storage.cache),
      totalItems)
    UI.TextArea.draw(self)
  end

  function overviewTab:enable()
    self.handle = Event.onInterval(5, function()
      self.textArea:draw()
      self:sync()
    end)
    UI.Tab.enable(self)
  end

  function overviewTab:disable()
    Event.off(self.handle)
  end

  UI:setPage(page)
  return page
end

local pages = { }

--[[ Task ]]--
local task = {
  name = 'status',
  priority = 99,
}

function task:cycle()
  for node in context.storage:filterActive('status') do
    if not pages[node.name] then
      pages[node.name] = createPage(node)
    end
  end
end

Milo:registerTask(task)
