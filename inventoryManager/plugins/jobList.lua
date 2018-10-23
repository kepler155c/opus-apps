local Lora       = require('lora')
local Peripheral = require('peripheral')
local UI         = require('ui')

local colors     = _G.colors

local context = Lora:getContext()
local mon     = Peripheral.lookup(context.config.monitor) or
                error('Monitor is not attached')
local display = UI.Device {
  device = mon,
  textScale = .5,
}

local jobList = UI.Page {
  parent = display,
  grid = UI.Grid {
    sortColumn = 'displayName',
    backgroundFocusColor = colors.black,
    columns = {
      { heading = 'Qty',      key = 'count',       width = 6                      },
      { heading = 'Crafting', key = 'displayName', width = display.width / 2 - 10 },
      { heading = 'Status',   key = 'status',      width = display.width - 10     },
    },
  },
}

function jobList:showError(msg)
  self.grid:clear()
  self.grid:centeredWrite(math.ceil(self.grid.height / 2), msg)
  self:sync()
end

function jobList:updateList(craftList)
  self.grid:setValues(craftList)
  self.grid:update()
  self:draw()
  self:sync()
end

function jobList.grid:getRowTextColor(row, selected)
  if row.statusCode == Lora.STATUS_ERROR then
    return colors.red
  elseif row.statusCode == Lora.STATUS_WARNING then
    return colors.yellow
  elseif row.statusCode == Lora.STATUS_INFO then
    return colors.lime
  end
  return UI.Grid:getRowTextColor(row, selected)
end

jobList:enable()
jobList:draw()
jobList:sync()

local JobListTask = {
  priority = 80,
}

function JobListTask:cycle()
  jobList:updateList(Lora:getCraftingStatus())
end

Lora:registerTask(JobListTask)
context.jobList = jobList
