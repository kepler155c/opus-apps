local Config = require('config')
local UI     = require('ui')
local itemDB = require('itemDB')

local args   = { ... }
local colors = _G.colors
local device = _G.device
local ni     = device.neuralInterface

local context = args[1]

if not context.state.depositAll then
  context.state.depositAll = { }
end

local page = UI.Page {
  titleBar = UI.TitleBar {
    backgroundColor = colors.gray,
    title = 'Deposit full inventory',
    previousPage = true,
  },
  items = UI.ScrollingGrid {
    x = 2, ex = -2, y = 2, ey = -4,
    columns = {
      { heading = 'Qty',  key = 'count',       width = 3 },
      { heading = 'Name', key = 'displayName',           },
    },
    sortColumn = 'count',
    inverseSort = true
  },
  form = UI.Form {
    x = 2, ex = -2, y = -2, ey = -2,
    margin = 1,
    [1] = UI.Checkbox {
      formLabel = 'Include hotbar', formKey = 'includeHotbar',
      help = 'Also send the contents of the hotbar to Milo (excluding the neural connector)'
    }
  },  
  notification = UI.Notification(),
}

local function makeKey(item)
  local damage = item.maxDamage == 0 and item.damage
  return itemDB:makeKey({ name = item.name, damage = damage })
end

function page:updateInventoryList() 
  local inv = ni.getInventory().list()
  local list = { }

  for slot, item in pairs(inv) do
    if (context.state.depositAll.includeHotbar or slot > 9) and item.name ~= 'plethora:neuralconnector' then
      local key = itemDB:makeKey(item)
      if not list[key] then
        local cItem = itemDB:get(item, function() return ni.getInventory().getItemMeta(slot) end)
        if cItem then
          cItem.key = makeKey(cItem)
          list[key] = cItem
        end
      else
        list[key].count = list[key].count + item.count
      end
    end
  end

  self.items:setValues(list)
  self.items:draw()
  itemDB:flush()
end

function page:enable()
  self.form:setValues(context.state.depositAll)
  self:updateInventoryList()
  UI.Page.enable(self)
end

function page:depositAll()
  self.notification:info('Depositing all items...')

  local inv = ni.getInventory().list()

  for slot, item in pairs(inv) do
    if (context.state.depositAll.includeHotbar or slot > 9) and item.name ~= 'plethora:neuralconnector' then
      context.page:sendRequest({
        request = 'deposit',
        slot = slot,
        count = item.count,
      })
    end
  end
end

function page:eventHandler(event)
  if event.type == 'checkbox_change' and event.element.formKey == 'includeHotbar' then
    context.state.depositAll.includeHotbar = event.checked
    page:updateInventoryList()
  elseif event.type == 'form_complete' then
    Config.update('miloRemote', context.state)
    page:depositAll()
    UI:setPreviousPage()
  elseif event.type == 'form_cancel' then
    UI:setPreviousPage()
  else
    return UI.Page.eventHandler(self, event)
  end
end

return {
  menuItem = 'Deposit all',
  callback = function()
    UI:setPage(page)
  end,
}
