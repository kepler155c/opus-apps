local InventoryAdapter = require('core.inventoryAdapter')
local Config         = require('config')
local Event          = require('event')
local itemDB         = require('core.itemDB')
local UI             = require('ui')
local Util           = require('util')

local colors         = _G.colors
local multishell     = _ENV.multishell
local rs             = _G.rs

local RESOURCE_FILE = 'usr/config/levelEmitter.db'

multishell.setTitle(multishell.getCurrent(), 'Level Emitter')

local config = {
  inventorySide = 'bottom',
}
Config.loadWithCheck('levelEmitter', config)

local inventoryAdapter = InventoryAdapter.wrap({ wrapSide = config.inventorySide })
if not inventoryAdapter then
  error('No inventory found')
end

local resources

local function getItem(items, inItem, ignoreDamage, ignoreNbtHash)
  for _,item in pairs(items) do
    if item.name == inItem.name and
      (ignoreDamage or item.damage == inItem.damage) and
      (ignoreNbtHash or item.nbtHash == inItem.nbtHash) then
      return item
    end
  end
end

local function uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

local function mergeResources(t)
  for _,v in pairs(resources) do
    local item = getItem(t, v)
    if item then
      Util.merge(item, v)
    else
      item = Util.shallowCopy(v)
      item.count = 0
      table.insert(t, item)
    end
  end

  for _,v in pairs(t) do
    if not v.displayName then
      v.displayName = itemDB:getName(v)
    end
    v.lname = v.displayName:lower()
  end
end

local function getItemWithQty(items, res, ignoreDamage, ignoreNbtHash)
  local item = getItem(items, res, ignoreDamage, ignoreNbtHash)

  if item and (ignoreDamage or ignoreNbtHash) then
    local count = 0

    for _,v in pairs(items) do
      if item.name == v.name and
        (ignoreDamage or item.damage == v.damage) and
        (ignoreNbtHash or item.nbtHash == v.nbtHash) then
        count = count + v.count
      end
    end
    item.count = count
  end

  return item
end

local function loadResources()
  resources = Util.readTable(RESOURCE_FILE) or { }
  for k,v in pairs(resources) do
    Util.merge(v, itemDB:splitKey(k))
  end
end

local function saveResources()
  local t = { }

  for k,v in pairs(resources) do
    v = Util.shallowCopy(v)
    local keys = Util.transpose({ 'limit', 'low', 'ignoreDamage', 'ignoreNbtHash' })

    for _,key in pairs(Util.keys(v)) do
      if not keys[key] then
        v[key] = nil
      end
    end
    if not Util.empty(v) then
      t[k] = v
    end
  end

  Util.writeTable(RESOURCE_FILE, t)
end

local itemPage = UI.Page {
  titleBar = UI.TitleBar {
    title = 'Limit Resource',
    previousPage = true,
    event = 'form_cancel',
  },
  form = UI.Form {
    x = 1, y = 2, height = 10, ex = -1,
    [1] = UI.TextEntry {
      width = 7,
      formLabel = 'Min', formKey = 'low', help = 'Output a signal if below'
    },
    [2] = UI.TextEntry {
      width = 7,
      formLabel = 'Max', formKey = 'limit', help = 'Output a signal if above'
    },
    [4] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Ignore damage of item'
    },
    [5] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore NBT', formKey = 'ignoreNbtHash',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Ignore NBT of item'
    },
  },
  statusBar = UI.StatusBar { }
}

function itemPage:enable(item)
  self.item = Util.shallowCopy(item)

  self.form:setValues(item)
  self.titleBar.title = item.displayName or item.name

  UI.Page.enable(self)
  self:focusFirst()
end

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local filtered = Util.shallowCopy(self.form.values)

    if filtered.ignoreDamage == true then
      filtered.damage = 0
    else
      filtered.ignoreDamage = nil
    end

    if filtered.ignoreNbtHash == true then
      filtered.nbtHash = nil
    else
      filtered.ignoreNbtHash = nil
    end

    local originalKey = uniqueKey(self.item)
    resources[originalKey] = nil

    filtered.low = tonumber(filtered.low)
    filtered.limit = tonumber(filtered.limit)
    if filtered.limit or filtered.low then
      resources[uniqueKey(filtered)] = filtered
    else
      resources[uniqueKey(filtered)] = nil
    end

    saveResources()

    UI:setPreviousPage()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Forget',  event = 'forget'  },
      { text = 'Refresh', event = 'refresh', x = -9 },
    },
  },
  grid = UI.Grid {
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'displayName' , width = 22 },
      { heading = 'Qty',  key = 'count'       , width = 5  },
      { heading = 'Min',  key = 'limit'       , width = 4  },
      { heading = 'Max',  key = 'low'       , width = 4  },
    },
    sortColumn = 'displayName',
  },
  statusBar = UI.StatusBar {
    filterText = UI.Text {
      x = 2,
      value = 'Filter',
    },
    filter = UI.TextEntry {
      x = 9, ex = -5,
      limit = 50,
      backgroundColor = colors.gray,
      backgroundFocusColor = colors.gray,
    },
    display = UI.Button {
      x = -3,
      event = 'toggle_display',
      value = 0,
      text = 'A',
    },
  },
  accelerators = {
    r = 'refresh',
    q = 'quit',
  },
  displayMode = 0,
}

function listingPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.count = Util.toBytes(row.count)
  if row.low then
    row.low = Util.toBytes(row.low)
  end
  if row.limit then
    row.limit = Util.toBytes(row.limit)
  end
  return row
end

function listingPage:eventHandler(event)
  if event.type == 'quit' then
    UI:exitPullEvents()

  elseif event.type == 'grid_select' then
    local selected = event.selected
    UI:setPage('item', selected)

  elseif event.type == 'refresh' then
    self:refresh()
    self.grid:draw()
    self.statusBar.filter:focus()

  elseif event.type == 'toggle_display' then
    local values = {
      [0] = 'A',
      [1] = 'I',
      [2] = 'C',
    }

    event.button.value = (event.button.value + 1) % 3
    self.displayMode = event.button.value
    event.button.text = values[event.button.value]
    event.button:draw()
    self:applyFilter()
    self.grid:draw()

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then
      local key = uniqueKey(item)

      if resources[key] then
        resources[key] = nil
        saveResources()
      end

      self.statusBar:timedStatus('Forgot: ' .. item.name, 3)
      self:refresh()
      self.grid:draw()
    end

  elseif event.type == 'text_change' then
    self.filter = event.text
    if #self.filter == 0 then
      self.filter = nil
    end
    self:applyFilter()
    self.grid:draw()
    self.statusBar.filter:focus()

  else
    UI.Page.eventHandler(self, event)
  end
  return true
end

function listingPage:enable()
  self:refresh()
  self:setFocus(self.statusBar.filter)
  UI.Page.enable(self)
end

function listingPage:refresh()
  self.allItems = inventoryAdapter:listItems()
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local filter = self.filter
  local displayMode = self.displayMode
  local t = self.allItems

  if filter or displayMode > 0 then
    t = { }
    if filter then
      filter = filter:lower()
    end
    for _,v in pairs(self.allItems) do
      if not filter or string.find(v.lname, filter, 1, true) then
        if not displayMode or
          displayMode == 0 or
          displayMode == 1 and v.count > 0 or
          displayMode == 2 and v.has_recipe then
          table.insert(t, v)
        end
      end
    end
  end

  self.grid:setValues(t)
end

loadResources()

UI:setPages({
  listing = listingPage,
  item = itemPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

Event.onInterval(5, function()
  local items = inventoryAdapter:listItems()

  if items and Util.size(items) > 0 then
    for _,res in pairs(resources) do
      local item = getItemWithQty(items, res, res.ignoreDamage, res.ignoreNbtHash)
      rs.setOutput('bottom', (res.limit and
                              item and item.count > res.limit) or
                             (res.low and
                              (not item or item.count < res.low)) or false)
    end
  end
end)

UI:pullEvents()
