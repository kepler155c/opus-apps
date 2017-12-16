_G.requireInjector()

local ChestAdapter   = require('chestAdapter18')
local Config         = require('config')
local Event          = require('event')
local itemDB         = require('itemDB')
local Peripheral     = require('peripheral')
local UI             = require('ui')
local Terminal       = require('terminal')
local Util           = require('util')

local colors     = _G.colors
local multishell = _ENV.multishell
local turtle     = _G.turtle

multishell.setTitle(multishell.getCurrent(), 'Crafter')

local config = {
  inventory = { direction = 'north', wrapSide = 'front' },
}
Config.load('crafter', config)

repeat until not turtle.forward()
local inventoryAdapter = ChestAdapter(config.inventory)

local RESOURCE_FILE = 'usr/config/resources.db'
local RECIPES_FILE  = 'usr/config/recipes2.db'

local recipes = Util.readTable(RECIPES_FILE) or { }
local resources
local machines = { }
local jobListGrid
local lastItems

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

local function uniqueKey(item)
  return table.concat({ item.name, item.damage, item.nbtHash }, ':')
end

local function getItemQuantity(items, res)
  local count = 0
  for _,v in pairs(items) do
    if res.name == v.name and
      ((not res.damage and v.maxDamage > 0) or res.damage == v.damage) and
      ((not res.nbtHash and v.nbtHash) or res.nbtHash == v.nbtHash) then
      count = count + v.count
    end
  end
  return count
end

local function getItemWithQty(items, res)
  for _,v in pairs(items) do
    if res.name == v.name and
      ((not res.damage and v.maxDamage > 0) or res.damage == v.damage) and
      ((not res.nbtHash and v.nbtHash) or res.nbtHash == v.nbtHash) then
      return v
    end
  end
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
    local v = itemDB:splitKey(k)
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
  for _ = 1, machine do
    if not turtle.back() then
      return
    end
  end
  return true
end

local function canCraft(recipe, items, count)
  count = math.ceil(count / recipe.count)

  local icount = Util.size(recipe.ingredients)
  local maxSlots = math.floor(16 / icount)

  for key,qty in pairs(recipe.ingredients) do
    local item = getItem(items, itemDB:splitKey(key))
    if not item then
      return 0, itemDB:getName(key)
    end
    local x = math.min(math.floor(item.count / qty), item.maxCount * maxSlots)
    count = math.min(x, count)
  end

  return count, ''
end

local function craftItem(recipe, recipeKey, items, cItem, count)
  repeat until not turtle.forward()

  local resource = resources[recipeKey]
  if not resource or not resource.machine then
    cItem.status = 'machine not selected'
    return false
  end

  if count == 0 then
    cItem.status = 'missing something'
    return false
  end

  local slot = 1
  for key,qty in pairs(recipe.ingredients) do
    local item = itemDB:get(key)
    if not item then
      cItem.status = 'failed'
      return false
    end
    local c = count * qty
    while c > 0 do
      local maxCount = math.min(c, item.maxCount)
      inventoryAdapter:provide(item, maxCount, slot)
      if turtle.getItemCount(slot) == 0 then -- ~= maxCount then FIXXX !!!
        cItem.status = 'failed'
        return false
      end
      c = c - maxCount
      slot = slot + 1
    end
  end
  if not gotoMachine(resource.machine) then
    cItem.status = 'failed to find machine'
  else
    if resource.dir == 'up' then
      turtle.emptyInventory(turtle.dropUp)
    else
      turtle.emptyInventory(turtle.dropDown)
    end
    if #turtle.getFilledSlots() ~= 0 then
      cItem.status = 'machine busy'
    else
      cItem.status = 'crafting'
    end
  end
end

local function expandList(list)
  local items = lastItems

  local function getCraftable(recipe, count)
    local maxSlots = math.floor(16 / Util.size(recipe.ingredients))

    for key,qty in pairs(recipe.ingredients) do

      local item = getItemWithQty(items, itemDB:splitKey(key))
      if not item then
        item = itemDB:get(key)
        if not item then
          --item = itemDB:splitKey(key)
          break
        end
        item.count = 0
      end

      local need = qty * count
      local irecipe = recipes[key]

      if item.count < need and irecipe then
        need = math.ceil((need - item.count) / irecipe.count)
        if not list[key] then
          list[key] = Util.shallowCopy(item)
          list[key].ocount = need
          list[key].count = 0
        else
          if not list[key].ocount then
            list[key].ocount = 0
          end
          list[key].ocount = list[key].ocount + need
        end

        local icount = getCraftable(irecipe, need)
        list[key].count = list[key].count + icount
      end
      local x = math.min(math.floor(item.count / qty), item.maxCount * maxSlots)
      count = math.min(x, count)
      item.count = math.max(0, item.count - (count * qty))
    end

    return count
  end

--[[
list = { }
debug(getCraftable(recipes['minecraft:brick:0'], 512))
for key, item in pairs(list) do
  debug(item.name .. ' : ' .. item.ocount .. ':' .. item.count)
end
read()
]]

  for key, item in pairs(Util.shallowCopy(list)) do
    local recipe = recipes[key]

    item.count = math.ceil(item.count / recipe.count)
    item.ocount = item.count
    if recipe then
      item.count = getCraftable(recipe, item.count)
    end
  end
end

local function craftItems(craftList)
  expandList(craftList)
  jobListGrid:update()
  jobListGrid:draw()
  jobListGrid:sync()
  for key, item in pairs(craftList) do
    local recipe = recipes[key]
    if recipe then
      craftItem(recipe, key, lastItems, item, item.count)
      repeat until not turtle.forward()
      jobListGrid:update()
      jobListGrid:draw()
      jobListGrid:sync()
      clearGrid()
      lastItems = inventoryAdapter:listItems() -- refresh counts
    end
  end
end

local function watchResources(items)
  local craftList = { }

  for _,res in pairs(resources) do
    if res.low then
      local item = Util.shallowCopy(res)
      item.nbtHash = res.nbtHash
      item.damage = res.damage
      if res.ignoreDamage then
        item.damage = nil
      end
      item.count = getItemQuantity(items, item)
      if item.count < res.low then
        item.displayName = itemDB:getName(res)
        item.count = res.low - item.count
        craftList[uniqueKey(res)] = item
      end
    end
  end

  return craftList
end

local function loadResources()
  resources = Util.readTable(RESOURCE_FILE) or { }
  for k,v in pairs(resources) do
    Util.merge(v, itemDB:splitKey(k))
    if not v.machine then
      local recipe = recipes[k]
      v.machine = recipe.machine
      v.dir = recipe.dir or 'down'
    end
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

  local function getName(side)
    local p = Peripheral.getBySide(side)
    if p and p.getMetadata then
      local name = p.getMetadata().displayName
      if name and not string.find(name, '.', 1, true) then
        return name
      end
    end
  end

  local index = 0
  local t = { }

  local function getMachine(dir)
    local side = turtle.getAction(dir).side
    local machine = Peripheral.getBySide(side)
    if not machine then
      local _
      _, machine = turtle.getAction(dir).inspect()
    end
    if machine and type(machine) == 'table' then
      local rawName = getName(side) or machine.name
      local name = rawName
      local i = 1
      while t[name] do
        name = rawName .. '_' .. i
        i = i + 1
      end
      t[name] = true

      table.insert(machines, {
        name = name,
        index = index,
        dir = dir,
        order = #machines + 1
      })
    end
  end

  repeat
    getMachine('down')
    getMachine('up')
    index = index + 1
  until not turtle.back()
end

local function jobMonitor()
  local mon = Peripheral.getByType('monitor')

  if mon then
    mon = UI.Device({
      device = mon,
      textScale = .5,
    })
  else
    mon = UI.Device({
      device = Terminal.getNullTerm(term.current())
    })
  end

  jobListGrid = UI.Grid({
    parent = mon,
    sortColumn = 'displayName',
    columns = {
      { heading = 'Qty',      key = 'ocount',      width = 6 },
      { heading = 'Qty',      key = 'count',       width = 6 },
      { heading = 'Crafting', key = 'displayName', width = (mon.width - 18) / 2 },
      { heading = 'Status',   key = 'status', },
    },
  })

  function jobListGrid:getRowTextColor(row, selected)
    if row.status == '(no recipe)'then
      return colors.red
    elseif row.statusCode == 'missing' then
      return colors.yellow
    end

    return UI.Grid:getRowTextColor(row, selected)
  end

  jobListGrid:draw()
  jobListGrid:sync()
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
    [3] = UI.Button {
      text = 'Select', event= 'selectMachine',
      formLabel = 'Machine'
    },
    button = UI.Button {
      x = 2, y = 9,
      text = 'Recipe', event = 'learn',
    },
  },
  machines = UI.SlideOut {
    backgroundColor = colors.cyan,
    grid = UI.ScrollingGrid {
      y = 2, ey = -4,
      values = machines,
      disableHeader = true,
      columns = {
        { heading = '', key = 'index', width = 2 },
        { heading = 'Name', key = 'name'},
      },
      sortColumn = 'order',
    },
    button1 = UI.Button {
      x = -14, y = -2,
      text = 'Ok', event = 'setMachine',
    },
    button2 = UI.Button {
      x = -9, y = -2,
      text = 'Cancel', event = 'cancelMachine',
    },
    statusBar = UI.StatusBar(),
  },
  statusBar = UI.StatusBar { }
}

function itemPage:enable(item)
  if item then
    self.item = Util.shallowCopy(item)
    self.form:setValues(item)
    self.titleBar.title = item.displayName or item.name
  end
  UI.Page.enable(self)
  self:focusFirst()
end

function itemPage.machines:draw()
  UI.Window.draw(self)
  self:centeredWrite(1, 'Select machine', nil, colors.yellow)
end

function itemPage.machines:eventHandler(event)
  if event.type == 'grid_focus_row' then
    self.statusBar:setStatus(string.format('%d %s', event.selected.index, event.selected.dir))
  else
    return UI.SlideOut.eventHandler(self, event)
  end
  return true
end

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'learn' then
    UI:setPage('learn', self.item)

  elseif event.type == 'setMachine' then
    self.item.machine = self.machines.grid:getSelected().index
    self.item.dir = self.machines.grid:getSelected().dir
    self.machines:hide()

  elseif event.type == 'cancelMachine' then
    self.machines:hide()

  elseif event.type == 'selectMachine' then
    self.machines.grid:update()
    if self.item.machine then
      local _, index = Util.find(machines, 'index', self.item.machine)
      if index then
        self.machines.grid:setIndex(index)
      end
    end
    self.machines:show()

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local values = self.form.values
    local keys = { 'name', 'low', 'damage', 'nbtHash', 'machine' }

    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end
    filtered.low = tonumber(filtered.low)
    filtered.machine = self.item.machine
    filtered.dir = self.item.dir

    if values.ignoreDamage == true then
      filtered.damage = 0
      filtered.ignoreDamage = true
    end

    local key = uniqueKey(filtered)

    resources[key] = filtered
    saveResources()

    UI:setPreviousPage()

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local learnPage = UI.Page {
  ingredients = UI.ScrollingGrid {
    y = 2, height = 3,
    disableHeader = true,
    columns = {
      { heading = 'Name', key = 'displayName', width = 31 },
      { heading = 'Qty',  key = 'count'      , width = 5  },
    },
    sortColumn = 'displayName',
  },
  grid = UI.ScrollingGrid {
    y = 6, height = 5,
    disableHeader = true,
    columns = {
      { heading = 'Name', key = 'displayName', width = 31 },
      { heading = 'Qty',  key = 'count'      , width = 5  },
    },
    sortColumn = 'displayName',
  },
  filter = UI.TextEntry {
    x = 20, ex = -2, y = 5,
    limit = 50,
    shadowText = 'filter',
    backgroundColor = colors.lightGray,
    backgroundFocusColor = colors.lightGray,
  },
  count = UI.TextEntry {
    x = 11, y = -1, width = 5,
    limit = 50,
  },
  button1 = UI.Button {
    x = -14, y = -1,
    text = 'Ok', event = 'accept',
  },
  button2 = UI.Button {
    x = -9, y = -1,
    text = 'Cancel', event = 'cancel',
  },
}

function learnPage:enable(target)
  self.target = target
  self.allItems = lastItems
  mergeResources(self.allItems)

  self.filter.value = ''
  self.grid.values = self.allItems
  self.grid:update()
  self.ingredients.values = { }
  self.count.value = 1

  if target.has_recipe then
    local recipe = recipes[uniqueKey(target)]
    self.count.value = recipe.count
    for k,v in pairs(recipe.ingredients) do
      self.ingredients.values[k] =
        { name = k, count = v, displayName = itemDB:getName(k) }
    end
  end
  self.ingredients:update()

  self:setFocus(self.filter)
  UI.Page.enable(self)
end

function learnPage:draw()
  UI.Window.draw(self)
  self:write(2, 1, 'Ingredients', nil, colors.yellow)
  self:write(2, 5, 'Inventory', nil, colors.yellow)
  self:write(2, 12, 'Produces')
end

function learnPage:eventHandler(event)

  if event.type == 'text_change' and event.element == self.filter then
    local t = filterItems(learnPage.allItems, event.text)
    self.grid:setValues(t)
    self.grid:draw()

  elseif event.type == 'cancel' then
    UI:setPreviousPage()

  elseif event.type == 'accept' then

    local recipe = {
      count = tonumber(self.count.value) or 1,
      ingredients = { },
    }
    for key, item in pairs(self.ingredients.values) do
      recipe.ingredients[key] = item.count
    end
    recipes[uniqueKey(self.target)] = recipe
    Util.writeTable(RECIPES_FILE, recipes)

    UI:setPreviousPage()

  elseif event.type == 'grid_select' then
    if event.element == self.grid then
      local key = uniqueKey(event.selected)
      if not self.ingredients.values[key] then
        self.ingredients.values[key] = Util.shallowCopy(event.selected)
        self.ingredients.values[key].count = 0
      end
      self.ingredients.values[key].count = self.ingredients.values[key].count + 1
      self.ingredients:update()
      self.ingredients:draw()
    elseif event.element == self.ingredients then
      event.selected.count = event.selected.count - 1
      if event.selected.count == 0 then
        self.ingredients.values[uniqueKey(event.selected)] = nil
        self.ingredients:update()
      end
      self.ingredients:draw()
    end

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

local listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Forget',  event = 'forget'  },
      { text = 'Refresh', event = 'refresh' },
    },
  },
  grid = UI.Grid {
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'displayName' },
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
  self.allItems = lastItems
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

loadResources()
findMachines()
repeat until not turtle.forward()
clearGrid()
jobMonitor()
lastItems = inventoryAdapter:listItems()

UI:setPages({
  listing = listingPage,
  item = itemPage,
  learn = learnPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

Event.on('turtle_abort', function()
  UI:exitPullEvents()
end)

Event.onInterval(30, function()
  repeat until not turtle.forward()
  if turtle.getFuelLevel() < 100 then
    turtle.select(1)
    inventoryAdapter:provide({ name = 'minecraft:coal', damage = 1 }, 16, 1)
    turtle.refuel()
  end
  lastItems = inventoryAdapter:listItems()
  local craftList = watchResources(lastItems)

  jobListGrid:setValues(craftList)
  jobListGrid:update()
  jobListGrid:draw()
  jobListGrid:sync()

  craftItems(craftList)
end)

UI:pullEvents()
jobListGrid.parent:reset()
