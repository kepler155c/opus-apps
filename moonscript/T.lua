local Event = require('opus.event')
local UI = require('opus.ui')
local kernel
kernel = _G.kernel
local multishell
multishell = _ENV.multishell
local tasks = multishell and multishell.getTabs and multishell.getTabs() or kernel.routines
UI:configure('Tasks', ...)
local page = UI.Page({
  UI.MenuBar({
    buttons = {
      {
        text = 'Activate',
        event = 'activate'
      },
      {
        text = 'Terminate',
        event = 'terminate'
      },
      {
        text = 'Inspect',
        event = 'inspect'
      }
    }
  }),
  grid = UI.ScrollingGrid({
    y = 2,
    columns = {
      {
        heading = 'ID',
        key = 'uid',
        width = 3
      },
      {
        heading = 'Title',
        key = 'title'
      },
      {
        heading = 'Status',
        key = 'status'
      },
      {
        heading = 'Time',
        key = 'timestamp'
      }
    },
    values = tasks,
    sortColumn = 'uid',
    autospace = true,
    getDisplayValues = function(self, row)
      local elapsed = os.clock() - row.timestamp
      return {
        uid = row.uid,
        title = row.title,
        status = row.isDead and 'error' or coroutine.status(row.co),
        timestamp = elapsed < 60 and string.format("%ds", math.floor(elapsed)) or string.format("%sm", math.floor(elapsed / 6) / 10)
      }
    end
  }),
  accelerators = {
    ['control-q'] = 'quit',
    [' '] = 'activate',
    t = 'terminate'
  },
  eventHandler = function(self, event)
    local t = self.grid:getSelected()
    local _exp_0 = event.type
    if 'activate' == _exp_0 or 'grid_select' == _exp_0 then
      if t then
        return multishell.setFocus(t.uid)
      end
    elseif 'terminate' == _exp_0 then
      if t then
        return multishell.terminate(t.uid)
      end
    elseif 'inspect' == _exp_0 then
      if t then
        return multishell.openTab(_ENV, {
          path = 'sys/apps/Lua.lua',
          args = {
            t
          },
          focused = true
        })
      end
    elseif 'quit' == _exp_0 then
      return UI:quit()
    else
      return UI.Page.eventHandler(self, event)
    end
  end
})
Event.onInterval(1, function()
  page.grid:update()
  page.grid:draw()
  return page:sync()
end)
UI:setPage(page)
return UI:start()
