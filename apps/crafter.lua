_G.requireInjector()

local ChestAdapter   = require('chestAdapter18')
local Event          = require('event')
local itemDB         = require('itemDB')
local Peripheral     = require('peripheral')
local UI             = require('ui')
local Util           = require('util')

local colors     = _G.colors
local multishell = _ENV.multishell
local turtle     = _G.turtle

multishell.setTitle(multishell.getCurrent(), 'Crafter')

repeat until not turtle.forward()
local inventoryAdapter = ChestAdapter({ wrapSide = 'front', direction = 'north' })

local RESOURCE_FILE = 'usr/config/resources.db'
local RECIPES_FILE  = 'usr/etc/recipes2.db'

local craftingPaused = false
local recipes = Util.readTable(RECIPES_FILE) or { }
local resources
local machines = { }

local function getItem(items, inItem, ignoreDamage)
  for _,item in pairs(items) do
    if item.name == inItem.name then
      if ignoreDamage then
        return item
      elseif item.damage == inItem.damage and item.nbtHash == inItem.nbtHash then
        return item
      end
    end
  end
end

local function splitKey(key)
  local t = Util.split(key, '(.-):')
  local item = { }
  if #t[#t] > 8 then
    item.nbtHash = table.remove(t)
  end
  item.damage = tonumber(table.remove(t))
  item.name = table.concat(t, ':')
  return item
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

  for k in pairs(recipes) do
    local v = splitKey(k)
    local item = getItem(t, v)
    if not item then
      item = Util.shallowCopy(v)
      item.count = 0
      table.insert(t, item)
    end
    item.has_recipe = true
  end

  for _,v in pairs(t) do
    if not v.displayName then
      v.displayName = itemDB:getName(v)
    end
    v.lname = v.displayName:lower()
  end
end

local function filterItems(t, filter)
  if filter then
    local r = {}
    filter = filter:lower()
    for _,v in pairs(t) do
      if string.find(v.lname, filter) then
        table.insert(r, v)
      end
    end
    return r
  end
  return t
end

local function clearGrid()
  for i = 1, 16 do
    local count = turtle.getItemCount(i)
    if count > 0 then
      inventoryAdapter:insert(i, count)
      if turtle.getItemCount(i) ~= 0 then
        return false
      end
    end
  end
  return true
end

local function gotoMachine(machine)
  local _, k = Util.find(machines, 'name', machine)

  if not k then
    error('Unable to locate machine: ' .. tostring(machine))
  end

  for _ = 1, k - 1 do
    turtle.back()
  end
end

local function canCraft(recipe, items, count)
  count = math.ceil(count / recipe.count)

  for _,key in pairs(recipe.ingredients) do
    local item = getItem(items, splitKey(key))
    if not item then
      return 0
    end
    count = math.min(item.count, count)
  end

  return count
end

local function craftItem(recipe, items, count)
  repeat until not turtle.forward()
  count = canCraft(recipe, items, count)
  if count == 0 then
    return false
  end

  for k,v in pairs(recipe.ingredients) do
    local item = splitKey(v)
    inventoryAdapter:provide(item, count, k)
    if turtle.getItemCount(k) ~= count then
      return false
    end
  end
  gotoMachine(recipe.machine)
  turtle.emptyInventory(turtle.dropDown)
end

local function craftItems(craftList, items)
  for key, item in pairs(craftList) do
    local recipe = recipes[key]
    if recipe then
      craftItem(recipe, items, item.count)
      repeat until not turtle.forward()
      items = inventoryAdapter:listItems() -- refresh counts
    end
  end
end

local function getItemWithQty(items, res, ignoreDamage)
  local item = getItem(items, res, ignoreDamage)

  if item and ignoreDamage then
    local count = 0

    for _,v in pairs(items) do
      if item.name == v.name and item.nbtHash == v.nbtHash then
        if item.maxDamage > 0 or item.damage == v.damage then
          count = count + v.count
        end
      end
    end
    item.count = count
  end

  return item
end

local function watchResources(items)
  local craftList = { }

  for _,res in pairs(resources) do
    local item = getItemWithQty(items, res, res.ignoreDamage)
    if not item then
      item = {
        damage = res.damage,
        nbtHash = res.nbtHash,
        name = res.name,
        displayName = itemDB:getName(res),
        count = 0
      }
    end

    if res.low and item.count < res.low then
      if res.ignoreDamage then
        item.damage = 0
      end
      local key = uniqueKey(res)
      craftList[key] = {
        damage = item.damage,
        nbtHash = item.nbtHash,
        count = res.low - item.count,
        name = item.name,
        displayName = item.displayName,
        status = '',
      }
    end
  end
  return craftList
end

local function loadResources()
  resources = Util.readTable(RESOURCE_FILE) or { }
  for k,v in pairs(resources) do
    Util.merge(v, splitKey(k))
  end
end

local function saveResources()
  local t = { }

  for k,v in pairs(resources) do
    v = Util.shallowCopy(v)
    v.name = nil
    v.damage = nil
    v.nbtHash = nil
    t[k] = v
  end

  Util.writeTable(RESOURCE_FILE, t)
end

local function findMachines()
  repeat until not turtle.forward()

  local index = 0
  local t = { }
  repeat
    local machine = Peripheral.getBySide('bottom')
    if machine then
      local name = machine.name
      local i = 1
      while t[name] do
        name = machine.name .. '_' .. i
        i = i + 1
      end
      t[name] = true

      table.insert(machines, {
        value = name,
        name = name,
        index = index,
      })
    end
    index = index + 1
  until not turtle.back()
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
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min'
    },
    [2] = UI.Chooser {
      width = 7,
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Ignore damage of item'
    },
  },
  statusBar = UI.StatusBar { }
}

function itemPage:enable(item)
  self.item = item

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
    local values = self.form.values
    local keys = { 'name', 'low', 'damage', 'nbtHash', }

    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end
    filtered.low = tonumber(filtered.low)

    if values.ignoreDamage == true then
      filtered.damage = 0
      filtered.ignoreDamage = true
    end

    resources[uniqueKey(filtered)] = filtered
    saveResources()

    UI:setPreviousPage()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local learnPage = UI.Page {
  grid = UI.ScrollingGrid {
    y = 2, height = 3,
    disableHeader = true,
    columns = {
      { heading = 'Name', key = 'displayName' , width = 31 },
      { heading = 'Qty',  key = 'count'       , width = 5  },
    },
    sortColumn = 'displayName',
  },
  ingredients = UI.ScrollingGrid {
    y = 6, height = 3,
    values = machines,
    disableHeader = true,
    columns = {
      { heading = 'Name', key = 'displayName' , width = 31 },
      { heading = 'Qty',  key = 'count'       , width = 5  },
    },
    sortColumn = 'displayName',
  },
  machine = UI.Chooser {
    choices = machines,
    x = 10, ex = -2, y = -3,
  },
  filter = UI.TextEntry {
    x = 9, ex = -17, y = -1,
    limit = 50,
    backgroundColor = colors.gray,
    backgroundFocusColor = colors.gray,
  },
  accept = UI.Button {
    x = -14, y = -1,
    text = 'Ok', event = 'accept',
  },
  cancel = UI.Button {
    x = -9, y = -1,
    text = 'Cancel', event = 'cancel'
  },
}

function learnPage:enable(target)
  self.target = target
  self.filter.value = ''
  self.allItems = inventoryAdapter:listItems()
  mergeResources(self.allItems)
  self.grid.values = self.allItems
  self.grid:update()
  self.ingredients.values = { }
  self.ingredients:update()
  self:setFocus(self.filter)
  UI.Page.enable(self)
end

function learnPage:draw()
  UI.Page.draw(self)
  self:write(2, self.height - 2, 'Machine')
  self:centeredWrite(1, 'Inventory', nil, colors.yellow)
  self:centeredWrite(5, 'Ingredients', nil, colors.yellow)
  self:write(2, self.height, 'Filter')
end

function learnPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()
  elseif event.type == 'accept' then
    local recipe = {
      count = 1,
      ingredients = { },
      machine = self.machine.value,
    }
    for key in pairs(self.ingredients.values) do
      table.insert(recipe.ingredients, key)
    end
    recipes[uniqueKey(self.target)] = recipe
    Util.writeTable(RECIPES_FILE, recipes)

    UI:setPreviousPage()
  elseif event.type == 'grid_select' then
    local key = uniqueKey(event.selected)
    if not self.ingredients.values[key] then
      self.ingredients.values[key] = Util.shallowCopy(event.selected)
      self.ingredients.values[key].count = 0
    end
    self.ingredients.values[key].count = self.ingredients.values[key].count + 1
    self.ingredients:update()
    self.ingredients:draw()

  elseif event.type == 'text_change' then
    local t = filterItems(self.allItems, event.text)
    self.grid:setValues(t)
    self.grid:draw()
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Learn',   event = 'learn'   },
      { text = 'Forget',  event = 'forget'  },
      { text = 'Refresh', event = 'refresh', x = -9 },
    },
  },
  grid = UI.Grid {
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'displayName' , width = 22 },
      { heading = 'Qty',  key = 'count'       , width = 5  },
      { heading = 'Min',  key = 'low'         , width = 4  },
    },
    sortColumn = 'displayName',
  },
  statusBar = UI.StatusBar {
    filterText = UI.Text {
      x = 2,
      value = 'Filter',
    },
    filter = UI.TextEntry {
      x = 9, ex = -2,
      limit = 50,
      backgroundColor = colors.gray,
      backgroundFocusColor = colors.gray,
    },
  },
  accelerators = {
    r = 'refresh',
    q = 'quit',
  }
}

function listingPage.grid:getRowTextColor(row, selected)
  if row.is_craftable then
    return colors.yellow
  end
  if row.has_recipe then
    return colors.cyan
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function listingPage.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.count = Util.toBytes(row.count)
  if row.low then
    row.low = Util.toBytes(row.low)
  end
  return row
end

function listingPage.statusBar:draw()
  return UI.Window.draw(self)
end

function listingPage.statusBar.filter:eventHandler(event)
  if event.type == 'mouse_rightclick' then
    self.value = ''
    self:draw()
    local page = UI:getCurrentPage()
    page.filter = nil
    page:applyFilter()
    page.grid:draw()
    page:setFocus(self)
  end
  return UI.TextEntry.eventHandler(self, event)
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

  elseif event.type == 'learn' then
    UI:setPage('learn', self.grid:getSelected())

  elseif event.type == 'craft' then
    UI:setPage('craft', self.grid:getSelected())

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then
      local key = uniqueKey(item)

      if recipes[key] then
        recipes[key] = nil
        Util.writeTable(RECIPES_FILE, recipes)
      end

      if resources[key] then
        resources[key] = nil
        Util.writeTable(RESOURCE_FILE, resources)
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
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

loadResources()

UI:setPages({
  listing = listingPage,
  item = itemPage,
  learn = learnPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

findMachines()
repeat until not turtle.forward()
clearGrid()

Event.on('turtle_abort', function()
  UI:exitPullEvents()
end)

Event.onInterval(30, function()
  if not craftingPaused then
    repeat until not turtle.forward()
    if turtle.getFuelLevel() < 100 then
      turtle.select(1)
      inventoryAdapter:provide({ name = 'minecraft:coal', damage = 1 }, 16, 1)
      turtle.refuel()
    end
    local items = inventoryAdapter:listItems()
    local craftList = watchResources(items)
    craftItems(craftList, items)
  end
end)

UI:pullEvents()
