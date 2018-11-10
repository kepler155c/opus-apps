local Event      = require('event')
local Milo       = require('milo')
local Peripheral = require('peripheral')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors

local context = Milo:getContext()
local mon     = Peripheral.lookup(context.config.activityMonitor)

if not mon then
  return
end

local page = UI.Window {
  parent = UI.Device {
    device = mon,
    textScale = .5,
  },
  grid = UI.Grid {
    columns = {
      { heading = 'Qty',    key = 'count',       width = 6 },
      { heading = 'Change', key = 'change',      width = 6 },
      { heading = 'Rate',   key = 'rate',        width = 6 },
      { heading = 'Name',   key = 'displayName' },
    },
    sortColumn = 'displayName',
  },
}

function page.grid:getRowTextColor(row, selected)
  if row.lastCount and row.lastCount ~= row.count then
    return row.count > row.lastCount and colors.yellow or colors.lightGray
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function page.grid:getDisplayValues(row)
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

function page:reset()
  self.lastItems = nil
  self.grid:setValues({ })
  self.grid:clear()
  self.grid:draw()
end

function page:refresh()
  local t = context.storage.cache

  if not self.lastItems then
    self.lastItems = { }
    for k,v in pairs(t) do
      self.lastItems[k] = {
        displayName = v.displayName,
        initialCount = v.count,
      }
    end
    self.timestamp = os.clock()
    self.grid:setValues({ })

  else
    for _,v in pairs(self.lastItems) do
      v.lastCount = v.count
      v.count = nil
    end

    self.elapsed = os.clock() - self.timestamp

    for k,v in pairs(t) do
      local v2 = self.lastItems[k]
      if v2 then
        v2.count = v.count
      else
        self.lastItems[k] = {
          displayName = v.displayName,
          count = v.count,
          initialCount = 0,
        }
      end
    end

    local changedItems = { }
    for k,v in pairs(self.lastItems) do
      if not v.count then
        v.count = 0
      end
      if v.count ~= v.initialCount then
        v.change  = v.count - v.initialCount
        v.rate = Util.round(60 / self.elapsed * v.change, 1)
        changedItems[k] = v
      end
    end

    self.grid:setValues(changedItems)
  end
  self.grid:draw()
end

Event.onInterval(5, function()
  if context.storage:isOnline() then
    page:refresh()
    page:sync()
  else
    page.grid:clear()
    page.grid:centeredWrite(math.ceil(page.height / 2), 'Storage Offline')
    page:sync()
  end
end)

Event.on('monitor_touch', function(_, side)
  if side == mon.side then
    page:reset()
    page:sync()
  end
end)

page:draw()
page:sync()
