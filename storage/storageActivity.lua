local InventoryAdapter = require('core.inventoryAdapter')
local Event            = require('event')
local UI               = require('ui')
local Util             = require('util')

local colors     = _G.colors
local multishell = _ENV.multishell

local storage = InventoryAdapter.wrap()
if not storage then
  error('Not connected to a valid inventory')
end

multishell.setTitle(multishell.getCurrent(), 'Storage Activity')
UI:configure('StorageActivity', ...)

local changedPage = UI.Page {
  grid = UI.Grid {
    ey = -6,
    columns = {
      { heading = 'Qty',    key = 'count',       width = 6 },
      { heading = 'Change', key = 'change',      width = 6 },
      { heading = 'Rate',   key = 'rate',        width = 6 },
      { heading = 'Name',   key = 'displayName' },
    },
    sortColumn = 'displayName',
  },
  buttons = UI.Window {
    y = -5, height = 5,
    backgroundColor = colors.gray,
    prevButton = UI.Button {
      x = 2, y = 2, height = 3, width = 5,
      event = 'previous',
      backgroundColor = colors.lightGray,
      text = ' < '
    },
    resetButton = UI.Button {
      x = 8, y = 2, height = 3, ex = -8,
      event = 'reset',
      backgroundColor = colors.lightGray,
      text = 'Reset'
    },
    nextButton = UI.Button {
      x = -6, y = 2, height = 3, width = 5,
      event = 'next',
      backgroundColor = colors.lightGray,
      text = ' > '
    },
  },
  accelerators = {
    q = 'quit',
  }
}

function changedPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)

  local ind = '+'
  if row.change < 0 then
    ind = ''
  end

  row.change = ind .. Util.toBytes(row.change)
  row.count = Util.toBytes(row.count)
  row.rate = Util.toBytes(row.rate)

  return row
end

function changedPage:eventHandler(event)
  if event.type == 'reset' then
    self.lastItems = nil
    self.grid:setValues({ })
    self.grid:clear()
    self.grid:draw()

  elseif event.type == 'next' then
    self.grid:nextPage()

  elseif event.type == 'previous' then
    self.grid:previousPage()

  elseif event.type == 'quit' then
    Event.exitPullEvents()

  else
    return UI.Page.eventHandler(self, event)
  end

  return true
end

local function uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

function changedPage:refresh()
  local t = storage:listItems()

  if not t or Util.empty(t) then
    self.grid:clear()
    self.grid:centeredWrite(math.ceil(self.height/2), 'Communication failure')
    return
  end

  for k,v in pairs(t) do
    t[k] = Util.shallowCopy(v)
  end

  if not self.lastItems then
    self.lastItems = t
    self.timestamp = os.clock()
    self.grid:setValues({ })
  else
    self.elapsed = os.clock() - self.timestamp
    local changedItems = { }
    local found
    for _,v in pairs(self.lastItems) do
      found = false
      for k2,v2 in pairs(t) do
        if uniqueKey(v) == uniqueKey(v2) then
          if v.count ~= v2.count then
            local c = Util.shallowCopy(v2)
            c.lastCount = v.count
            table.insert(changedItems, c)
          end
          table.remove(t, k2)
          found = true
          break
        end
      end
      -- New item
      if not found then
        local c = Util.shallowCopy(v)
        c.lastCount = v.count
        c.count = 0
        table.insert(changedItems, c)
      end
    end
    -- No items left
    for _,v in pairs(t) do
      v.lastCount = 0
      table.insert(changedItems, v)
    end

    for _,v in pairs(changedItems) do
      v.change  = v.count - v.lastCount
      v.rate = Util.round(60 / self.elapsed * v.change, 1)
    end

    self.grid:setValues(changedItems)
  end
  self.grid:draw()
end

Event.onInterval(5, function()
  changedPage:refresh()
  changedPage:sync()
end)

UI:setPage(changedPage)
changedPage:draw()
UI:pullEvents()
