local Craft      = require('turtle.craft')
local itemDB     = require('itemDB')
local Milo       = require('milo')
local Peripheral = require('peripheral')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors

local context = Milo:getContext()
local mon     = Peripheral.lookup(context.config.monitor) or
                error('Monitor is not attached')

local jobList = UI.Page {
  parent = UI.Device {
    device = mon,
    textScale = .5,
  },
  grid = UI.Grid {
    sortColumn = 'index',
    backgroundFocusColor = colors.black,
    columns = {
      { heading = 'Qty',      key = 'remaining',   width = 4 },
      { heading = 'Crafting', key = 'displayName', },
      { heading = 'Status',   key = 'status',      },
      { heading = 'Progress', key = 'progress',    width = 8 },
    },
  },
}

function jobList:showError(msg)
  self.grid:clear()
  self.grid:centeredWrite(math.ceil(self.grid.height / 2), msg)
  self:sync()
end

function jobList:updateList(craftList)
  if not Milo:isCraftingPaused() then
    local t = { }
    for _,v in pairs(craftList) do
      table.insert(t, v)
      v.index = #t
      v.showRemaining = true
      for k2,v2 in pairs(v.ingredients) do
        if v2 ~= v then
          table.insert(t, v2)
          if not v2.displayName then
            v2.displayName = itemDB:getName(k2)
          end
          v2.index = #t
        end
      end
    end
    self.grid:setValues(t)
    self.grid:update()
    self:draw()
    self:sync()
  end
end

function jobList.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  if row.showRemaining then
    row.remaining = math.max(0, row.count - row.crafted)
  else
    row.displayName = '  ' .. row.displayName
  end
  row.progress = string.format('%d/%d', row.crafted, row.count)
  return row
end

function jobList.grid:getRowTextColor(row, selected)
  local statusColor = {
    [ Craft.STATUS_ERROR ] = colors.red,
    [ Craft.STATUS_WARNING ] = colors.orange,
    [ Craft.STATUS_INFO ] = colors.yellow,
    [ Craft.STATUS_SUCCESS ] = colors.green,
  }
  return row.statusCode and statusColor[row.statusCode] or
    UI.Grid:getRowTextColor(row, selected)
end

jobList:enable()
jobList:draw()
jobList:sync()

local JobListTask = {
  name = 'job status',
  priority = 80,
}

function JobListTask:cycle()
  jobList:updateList(context.craftingQueue)
end

Milo:registerTask(JobListTask)
context.jobList = jobList
