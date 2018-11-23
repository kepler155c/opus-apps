local Craft   = require('craft2')
local Event   = require('event')
local itemDB  = require('itemDB')
local Milo    = require('milo')
local UI      = require('ui')
local Util    = require('util')

local colors  = _G.colors
local context = Milo:getContext()
local device  = _G.device

--[[ Configuration Screen ]]
local wizardPage = UI.Window {
  title = 'Crafting Monitor',
  index = 2,
  backgroundColor = colors.cyan,
  [1] = UI.TextArea {
    x = 2, ex = -2, y = 2, ey = -2,
    marginRight = 0,
    textColor = colors.yellow,
    value = 'Displays the crafting progress.'
  },
}

function wizardPage:isValidType(node)
  local m = device[node.name]
  return m and m.type == 'monitor' and {
    name = 'Crafting Monitor',
    value = 'jobs',
    help = 'Display crafting progress / jobs'
  }
end

function wizardPage:isValidFor(node)
  return node.mtype == 'jobs'
end

UI:getPage('nodeWizard').wizard:add({ jobs = wizardPage })

--[[ Display ]]
-- TODO: some way to cancel a job
local function createPage(node)
  local page = UI.Page {
    parent = UI.Device {
      device = node.adapter,
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
  --      { heading = 'total',   key = 'total',  width = 4    },
  --      { heading = 'used',   key = 'used',   width = 4   },
  --      { heading = 'count',   key = 'count', width = 4     },
        { heading = 'crafted',   key = 'crafted',  width = 5    },
  --      { heading = 'Progress', key = 'progress',    width = 8 },
      },
    },
  }

  function page:updateList(craftList)
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

  function page.grid:getDisplayValues(row)
    row = Util.shallowCopy(row)
    if not row.displayName then
      row.displayName = itemDB:getName(row)
    end
    if row.requested then
      row.remaining = math.max(0, row.requested - row.crafted)
    else
      row.displayName = '  ' .. row.displayName
    end
    --row.progress = string.format('%d/%d', row.crafted, row.count)
    return row
  end

  function page.grid:getRowTextColor(row, selected)
    local statusColor = {
      [ Craft.STATUS_ERROR ] = colors.red,
      [ Craft.STATUS_WARNING ] = colors.orange,
      [ Craft.STATUS_INFO ] = colors.yellow,
      [ Craft.STATUS_SUCCESS ] = colors.green,
    }
    return row.statusCode and statusColor[row.statusCode] or
      UI.Grid:getRowTextColor(row, selected)
  end

  page:enable()
  page:draw()
  page:sync()

  return page
end

local pages = { }

Event.on({ 'milo_resume', 'milo_pause' }, function(_, reason)
  for node in context.storage:filterActive('jobs') do
    local page = pages[node.name]
    if page then
      if reason then
        page.grid:clear()
        page.grid:centeredWrite(math.ceil(page.grid.height / 2), reason.msg)
      else
        page.grid:draw()
      end
      page:sync()
    end
  end
end)

--[[ Task ]]
local task = {
  name = 'job status',
  priority = 80,
}

function task:cycle()
  for node in context.storage:filterActive('jobs') do
    if not pages[node.name] then
      pages[node.name] = createPage(node)
    end
    pages[node.name]:updateList(context.craftingQueue)
  end
end

Milo:registerTask(task)
