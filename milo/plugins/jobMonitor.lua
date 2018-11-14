local Ansi       = require('ansi')
local Craft      = require('turtle.craft')
local itemDB     = require('itemDB')
local Milo       = require('milo')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors
local context    = Milo:getContext()
local device     = _G.device
local monitor    = context.storage:getSingleNode('jobs')

--[[ Configuration Screen ]]
local template =
[[%sDisplays the crafting progress%s

%sMilo must be restarted to activate diplay.]]

local jobsWizardPage = UI.Window {
  title = 'Crafting Monitor',
  index = 2,
  backgroundColor = colors.cyan,
  [1] = UI.TextArea {
    x = 2, ex = -2, y = 2, ey = -2,
    marginRight = 0,
    value = string.format(template, Ansi.yellow, Ansi.reset, Ansi.orange),
  },
}

function jobsWizardPage:isValidType(node)
  local m = device[node.name]
  return m and m.type == 'monitor' and {
    name = 'Crafting Monitor',
    value = 'jobs',
    help = 'Display crafting progress / jobs'
  }
end

function jobsWizardPage:isValidFor(node)
  return node.mtype == 'jobs'
end

UI:getPage('nodeWizard').wizard:add({ jobs = jobsWizardPage })

--[[ Display ]]
if not monitor then
  return
end

-- TODO: some way to cancel a job

local jobMonitor = UI.Page {
  parent = UI.Device {
    device = monitor.adapter,
    textScale = .5,
  },
  grid = UI.Grid {
    sortColumn = 'index',
    backgroundFocusColor = colors.black,
    columns = {
      { heading = 'Qty',      key = 'remaining',   width = 4 },
      { heading = 'Crafting', key = 'displayName', },
      { heading = 'Status',   key = 'status',      },
      { heading = 'need',   key = 'need',    width = 4  },
      { heading = 'total',   key = 'total',  width = 4    },
      { heading = 'used',   key = 'used',   width = 4   },
      { heading = 'count',   key = 'count', width = 4     },
      { heading = 'crafted',   key = 'crafted',  width = 4    },
--      { heading = 'Progress', key = 'progress',    width = 8 },
    },
  },
}

function jobMonitor:showError(msg)
  self.grid:clear()
  self.grid:centeredWrite(math.ceil(self.grid.height / 2), msg)
  self:sync()
end

function jobMonitor:updateList(craftList)
  if not Milo:isCraftingPaused() then
    local t = { }
    for _,v in pairs(craftList) do
      table.insert(t, v)
      v.index = #t
      for k2,v2 in pairs(v.ingredients or { }) do
        if v2.key ~= v.key --[[and v2.statusCode ]] then
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

function jobMonitor.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  if row.requested then
    row.remaining = math.max(0, row.requested - row.crafted)
  else
    row.displayName = '  ' .. row.displayName
  end
  --row.progress = string.format('%d/%d', row.crafted, row.count)
  return row
end

function jobMonitor.grid:getRowTextColor(row, selected)
  local statusColor = {
    [ Craft.STATUS_ERROR ] = colors.red,
    [ Craft.STATUS_WARNING ] = colors.orange,
    [ Craft.STATUS_INFO ] = colors.yellow,
    [ Craft.STATUS_SUCCESS ] = colors.green,
  }
  return row.statusCode and statusColor[row.statusCode] or
    UI.Grid:getRowTextColor(row, selected)
end

jobMonitor:enable()
jobMonitor:draw()
jobMonitor:sync()

--[[ Task ]]
local jobMonitorTask = {
  name = 'job status',
  priority = 80,
}

function jobMonitorTask:cycle()
  jobMonitor:updateList(context.craftingQueue)
end

Milo:registerTask(jobMonitorTask)
context.jobMonitor = jobMonitor
