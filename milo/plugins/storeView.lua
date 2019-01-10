local Config     = require('config')
local Event      = require('event')
local itemDB     = require('itemDB')
local Milo       = require('milo')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors
local context    = Milo:getContext()
local os         = _G.os

local config = Config.load('store')

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
    grid = UI.Grid {
      ey = -6,
      columns = {
        { heading = 'Qty',     key = 'count',      width = 5 },
        { heading = 'Price',   key = 'price',      width = 5 },
        { heading = 'Name',    key = 'displayName' },
        { heading = 'Address', key = 'address',    width = 20 },
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
      nextButton = UI.Button {
        x = -6, y = 2, height = 3, width = 5,
        event = 'next',
        backgroundColor = colors.lightGray,
        text = ' > '
      },
    },
    timestamp = os.clock(),
  }

  function page.grid:getRowTextColor(row, selected)
    if row.count == 0 then
      return colors.gray
    end
    return UI.Grid:getRowTextColor(row, selected)
  end

  function page.grid:getDisplayValues(row)
    row = Util.shallowCopy(row)
    row.count = Util.toBytes(row.count)
    row.address = row.name .. '@' .. node.domain
    return row
  end

  function page:eventHandler(event)
    if event.type == 'next' then
      self.grid:nextPage()

    elseif event.type == 'previous' then
      self.grid:previousPage()

    else
      return UI.Page.eventHandler(self, event)
    end

    Event.onTimeout(.1, function()
      self:setFocus(self.grid)
      self:sync()
    end)
    return true
  end

  function page:refresh()
    local list = Milo:listItems()
    self.grid.values = { }
    for k,v in pairs(config) do
      local item = list[k]
      if item then
        table.insert(self.grid.values, {
          displayName = item.displayName,
          count = item.count,
          name = v.name,
          price = v.price,
        })
      else
        table.insert(self.grid.values, {
          displayName = itemDB:getName(k),
          count = 0,
          name = v.name,
          price = v.price,
        })
      end
    end
    self.grid:update()
    self.grid:draw()
  end

  function page:update()
    page:refresh()
    page:sync()
  end

  UI:setPage(page)
  return page
end

local pages = { }

-- called when an item to sell has been changed
Event.on('store_refresh', function()
  config = Config.load('store')
end)

--[[ Task ]]--
local StoreTask = {
  name = 'store',
  priority = 30,
}

function StoreTask:cycle()
  for node in context.storage:filterActive('store') do
    if not pages[node.name] then
      pages[node.name] = createPage(node)
    end
    -- update the display
    pages[node.name]:update()
  end
end

Milo:registerTask(StoreTask)
