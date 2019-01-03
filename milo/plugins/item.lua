local UI     = require('ui')
local Util   = require('util')

local fs     = _G.fs
local shell  = _ENV.shell

local function loadDirectory(dir)
  local tabs = { }
  for _, file in pairs(fs.list(dir)) do
    if not fs.isDir(fs.combine(dir, file)) then
      local s, m = Util.run(_ENV, fs.combine(dir, file))
      if not s and m then
        _G.printError('Error loading: ' .. file)
        error(m or 'Unknown error')
      end
      table.insert(tabs, m)
    end
  end
  return tabs
end

local programDir = fs.getDir(shell.getRunningProgram())
local tabs = loadDirectory(fs.combine(programDir, 'plugins/item'))

table.sort(tabs, function(a, b) return a.index < b.index end)

local page = UI.Page {
  titleBar = UI.TitleBar {
    title = 'Item settings',
    previousPage = true,
  },
  statusBar = UI.StatusBar { },
  notification = UI.Notification { },
}

function page:enable(item)
  for _, v in pairs(tabs) do
    if v.UIElement then
      v:setItem(item)
    end
  end
  self.tabs:selectTab(tabs[1])
  UI.Page.enable(self)
end

function page:eventHandler(event)
  if event.type == 'tab_activate' then
    event.activated:focusFirst()

  elseif event.type == 'form_invalid' then
    self.notification:error(event.message)

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'success_message' then
    self.notification:success(event.message)

  elseif event.type == 'info_message' then
    self.notification:info(event.message)

  elseif event.type == 'error_message' then
    self.notification:error(event.message)

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local t = Util.shallowCopy(tabs)
t.y = 2
t.ey = -2

page:add({ tabs = UI.Tabs(t) })

UI:addPage('item', page)
