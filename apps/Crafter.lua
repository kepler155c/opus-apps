_G.requireInjector()

local InventoryAdapter = require('inventoryAdapter')
local Config         = require('config')
local Event          = require('event')
local itemDB         = require('itemDB')
local Peripheral     = require('peripheral')
local UI             = require('ui')
local Terminal       = require('terminal')
local Util           = require('util')

local colors     = _G.colors
local os         = _G.os
local term       = _G.term
local turtle     = _G.turtle

local config = {
  computerFacing = 'north',
  inventorySide = 'front',
  monitor = 'type/monitor',
}
Config.load('crafter', config)

repeat until not turtle.forward()

local inventoryAdapter = InventoryAdapter.wrap({
  side = config.inventorySide,
  facing = config.computerFacing
})
if not inventoryAdapter then
  error('Invalid inventory configuration')
end

local RESOURCE_FILE    = 'usr/config/resources.db'
local RECIPES_FILE     = 'usr/config/recipes2.db'
local MACHINES_FILE    = 'usr/config/machines.db'

local STATUS_ERROR   = 'error'
local STATUS_INFO    = 'info'
local STATUS_SUCCESS = 'success'
local STATUS_WARNING = 'warning'

local recipes = Util.readTable(RECIPES_FILE) or { }
local resources
local machines = { }
local jobListGrid
local listing, docked = false, false

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

local function undock()
  while listing do
    os.sleep(.5)
  end
  docked = false
end

local function gotoMachine(machine)
  undock()
  for _ = 1, machine.index do
    if not turtle.back() then
      return
    end
  end

  return true
end

local function dock()
  if not docked then
    repeat until not turtle.forward()
  end
  docked = true
end

local function getItems()
  while not docked do
    os.sleep(.5)
  end

  listing = true

  local items
  for _ = 1, 5 do
    items = inventoryAdapter:listItems()
    if items then
      break
    end
  end
  if not items then
    error('could not check inventory')
  end

  listing = false

  return items
end

local function isMachineEmpty(machine, item)
  local side = turtle.getAction(machine.dir).side
  local methods = Util.transpose(Peripheral.getMethods(side))
  local list = { true }

  if methods.getAllStacks then -- 1.7x
    list = Peripheral.call(side, 'getAllStacks', false)
  elseif methods.list then
    list = Peripheral.call(side, 'list')
  elseif methods.getProgress then
    if Peripheral.call(side, 'getProgress') == 0 then
      return true
    end
  else
    item.statusCode = STATUS_ERROR
    item.status = 'Unable to check empty status'
    return
  end

  if tonumber(machine.ignoreSlot) then
    list[tonumber(machine.ignoreSlot)] = nil
  end

  if Util.empty(list) then
    return true
  end
  item.statusCode = STATUS_INFO
  item.status = 'machine busy'
end

local function craftItem(ikey, item, items, machineStatus)
  dock()

  local resource = resources[ikey]
  if not resource or not resource.machine then
    item.statusCode = STATUS_ERROR
    item.status = 'machine not defined'
    return
  end

  local machine = Util.find(machines, 'order', resource.machine)
  if not machine then
    item.statusCode = STATUS_ERROR
    item.status = 'invalid machine'
    return
  end

  local ms = machineStatus[machine.order]
  if not ms then
    ms = { count = 0 }
    machineStatus[machine.order] = ms
  end

  local slot = 1
  local maxCount = math.ceil(item.need / item.recipe.count)
  maxCount = math.min(machine.maxCount or 64, maxCount)

  if maxCount > 0 and maxCount - ms.count <= 0 then
    item.statusCode = STATUS_INFO
    item.status = 'machine busy'
    return
  end

  maxCount = maxCount - ms.count

  for key,qty in pairs(item.recipe.ingredients) do
    local ingredient = itemDB:get(key)
    local c = math.min(maxCount * qty, getItemQuantity(items, ingredient))
    c = math.min(c, ingredient.maxCount)
    c = math.floor(c / qty)
    if c < maxCount then
      maxCount = c
    end
    if maxCount <= 0 then
      item.status = 'Missing ' .. ingredient.displayName
      item.statusCode = STATUS_WARNING
      return
    end
  end

  if machine.maxCount then
    ms.count = ms.count + maxCount
  end

  turtle.setStatus('Craft: ' .. itemDB:getName(ikey))
  for key,qty in pairs(item.recipe.ingredients) do
    local ingredient = itemDB:get(key)
--    local c = item.craftable * qty
--    while c > 0 do
--debug(key)
    inventoryAdapter:provide(ingredient, maxCount * qty, slot)
    if turtle.getItemCount(slot) ~= maxCount * qty then -- ~= maxCount then FIXXX !!!
      item.status = 'Extract failed: ' .. (ingredient.displayName or itemDB:getName(ingredient))
      item.statusCode = STATUS_ERROR
      return
    end
--      c = c - maxCount
    slot = slot + 1
    --end
  end

  if not gotoMachine(machine) then
    item.status = 'failed to find machine'
    item.statusCode = STATUS_ERROR
  else
    if machine.empty and not isMachineEmpty(machine, item) then
      return
    end

    if machine.dir == 'up' then
      turtle.emptyInventory(turtle.dropUp)
    else
      turtle.emptyInventory(turtle.dropDown)
    end
    if #turtle.getFilledSlots() ~= 0 then
      item.statusCode = STATUS_INFO
      item.status = 'machine busy'
    else
      item.statusCode = STATUS_SUCCESS
      item.status = 'crafting'
    end
  end
end

local function expandList(list, items)
  local summed = { }

  local function sumItems(key, count)
    local item = itemDB:splitKey(key)
    local summedItem = summed[key]
    if not summedItem then
      summedItem = Util.shallowCopy(item)
      summedItem.recipe = recipes[key]
      summedItem.count = getItemQuantity(items, item)
      summedItem.displayName = itemDB:getName(item)
      summedItem.total = 0
      summedItem.need = 0
      summedItem.used = 0
      summedItem.craftable = 0
      summed[key] = summedItem
    end
    local total = count
    local used = math.min(summedItem.count, total)
    local need = total - used

    summedItem.total = summedItem.total + total
    summedItem.count = summedItem.count - used
    summedItem.used = summedItem.used + used
    summedItem.need = summedItem.need + need

    if need > 0 and summedItem.recipe then
      need = math.ceil(need / summedItem.recipe.count)
      for ikey,iqty in pairs(summedItem.recipe.ingredients) do
        sumItems(ikey, math.ceil(need * iqty))
      end
    end
  end

  for key, item in pairs(list) do
    sumItems(key, item.count)
  end

  return Util.filter(summed, function(a) return a.need > 0 end)
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
        item.count = res.low -- - item.count
        craftList[uniqueKey(res)] = item
      end
    end
  end

  return craftList
end

local function craftItems()
  local machineStatus = { }
  local items = getItems()
  local craftList = watchResources(items)
  local list = expandList(craftList, items)
  jobListGrid:setValues(list)
  jobListGrid:update()
  jobListGrid:draw()
  jobListGrid:sync()
  for key, item in pairs(list) do
    if item.need > 0 and item.recipe then
      craftItem(key, item, items, machineStatus)
      dock()
      items = getItems() -- should decrement count instead ...
      clearGrid()
    elseif item.need > 0 then
      item.status = 'no recipe'
      item.statusCode = STATUS_ERROR
    end
    jobListGrid:update()
    jobListGrid:draw()
    jobListGrid:sync()
  end
  turtle.setStatus('idle')
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

    v.name = nil
    v.damage = nil
    v.nbtHash = nil
    t[k] = v
  end

  Util.writeTable(RESOURCE_FILE, t)
end

local function findMachines()
  turtle.setStatus('Inspecting machines')

  dock()

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

  local function getMachine(dir)
    local side = turtle.getAction(dir).side
    local machine = Peripheral.getBySide(side)
    if not machine then
      local _
      _, machine = turtle.getAction(dir).inspect()
      if not machine or type(machine) ~= 'table' then
        machine = { name = 'Unknown' }
      end
    end
    if machine and type(machine) == 'table' then
      local name = getName(side) or machine.name
      table.insert(machines, {
        name = name,
        rawName = name,
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
    undock()
  until not turtle.back()

  local mf = Util.readTable(MACHINES_FILE) or { }
  for _,m in pairs(machines) do
    local m2 = Util.find(mf, 'order', m.order)
    if m2 then
      if not m2.rawName then
        m2.rawName = m.rawName
      end
      if m.rawName == m2.rawName then
        m.name = m2.name or m.name
      end
      m.empty = m2.empty
      m.ignore = m2.ignore
      m.ignoreSlot = m2.ignoreSlot
      m.maxCount = m2.maxCount
    end
  end
end

local function jobMonitor()
  local mon = Peripheral.lookup(config.monitor)

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
      { heading = 'Qty',      key = 'need',        width = 6 },
      { heading = 'Crafting', key = 'displayName', width = (mon.width - 18) / 2 },
      { heading = 'Status',   key = 'status', },
    },
  })

  function jobListGrid:getRowTextColor(row, selected)
    if row.statusCode == STATUS_ERROR then
      return colors.red
    elseif row.statusCode == STATUS_WARNING then
      return colors.yellow
    elseif row.statusCode == STATUS_SUCCESS then
      return colors.lime
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
    info = UI.TextArea {
      x = 2, ex = -2, y = 6, height = 3,
      textColor = colors.gray,
    },
    button = UI.Button {
      x = 2, y = 9,
      text = 'Recipe', event = 'learn',
    },
  },
  machines = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = 'Select Machine',
      previousPage = true,
    },
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

function itemPage.form.info:draw()
  local recipe = recipes[uniqueKey(itemPage.item)]
  if recipe and itemPage.item.machine then
    self.value = string.format('Crafts %d using the %s machine',
      recipe.count,
      machines[itemPage.item.machine].name)
  end
  UI.TextArea.draw(self)
end

--[[
function itemPage.machines:eventHandler(event)
  if event.type == 'grid_focus_row' then
    self.statusBar:setStatus(string.format('%d %s', event.selected.index, event.selected.dir))
  else
    return UI.SlideOut.eventHandler(self, event)
  end
  return true
end
]]

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'learn' then
    UI:setPage('learn', self.item)

  elseif event.type == 'setMachine' then
    self.item.machine = self.machines.grid:getSelected().order
    self.machines:hide()

  elseif event.type == 'cancelMachine' then
    self.machines:hide()

  elseif event.type == 'selectMachine' then
    local machineCopy = Util.shallowCopy(machines)
    Util.filterInplace(machineCopy, function(m) return not m.ignore end)
    self.machines.grid:setValues(machineCopy)
    if self.item.machine then
      local _, index = Util.find(machineCopy, 'order', self.item.machine)
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
  self.allItems = getItems()
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

local machinesPage = UI.Page {
  titleBar = UI.TitleBar {
    previousPage = true,
    title = 'Machines',
  },
  grid = UI.ScrollingGrid {
    y = 2, ey = -2,
    values = machines,
    columns = {
      { heading = 'Name',  key = 'name' },
      { heading = 'Side',  key = 'dir',   width = 5  },
      { heading = 'Index', key = 'index', width = 5  },
    },
    sortColumn = 'order',
  },
  detail = UI.SlideOut {
    backgroundColor = colors.cyan,
    form = UI.Form {
      x = 1, y = 2, ex = -1, ey = -2,
      [1] = UI.TextEntry {
        formLabel = 'Name', formKey = 'name', help = '...',
        limit = 64,
      },
      [2] = UI.Chooser {
        width = 7,
        formLabel = 'Hidden', formKey = 'ignore',
        nochoice = 'No',
        choices = {
          { name = 'Yes', value = true },
          { name = 'No', value = false },
        },
        help = 'Do not show this machine'
      },
      [3] = UI.Chooser {
        width = 7,
        formLabel = 'Empty', formKey = 'empty',
        nochoice = 'No',
        choices = {
          { name = 'Yes', value = true },
          { name = 'No', value = false },
        },
        help = 'Check if machine is empty before crafting'
      },
      [4] = UI.TextEntry {
        formLabel = 'Ignore Slot', formKey = 'ignoreSlot', help = '...',
        limit = 4,
      },
      [5] = UI.TextEntry {
        formLabel = 'Max Craft', formKey = 'maxCount', help = '...',
        limit = 4,
      },
    },
    statusBar = UI.StatusBar(),
  },
  statusBar = UI.StatusBar {
    values = 'Select Machine',
  },
  accelerators = {
    h = 'toggle_hidden',
  }
}

function machinesPage:enable()
  self.grid:update()
  UI.Page.enable(self)
end

function machinesPage.detail:eventHandler(event)
  if event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
  end
  return UI.SlideOut.eventHandler(self, event)
end

function machinesPage.grid:getRowTextColor(row, selected)
  if row.ignore then
    return colors.yellow
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function machinesPage:eventHandler(event)
  if event.type == 'grid_select' then
    self.detail.form:setValues(event.selected)
    self.detail:show()

  elseif event.type == 'toggle_hidden' then
    local selected = self.grid:getSelected()
    if selected then
      selected.ignore = not selected.ignore
      Util.writeTable(MACHINES_FILE, machines)
      self:draw()
    end

  elseif event.type == 'form_complete' then
    self.detail.form.values.empty = self.detail.form.values.empty == true
    self.detail.form.values.ignore = self.detail.form.values.ignore == true
    self.detail.form.values.ignoreSlot = tonumber(self.detail.form.values.ignoreSlot)
    self.detail.form.values.maxCount = tonumber(self.detail.form.values.maxCount)
    Util.writeTable(MACHINES_FILE, machines)
    self.detail:hide()

  elseif event.type == 'form_cancel' then
    self.detail:hide()

  else
    UI.Page.eventHandler(self, event)
  end
  return true
end

local listingPage = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Forget',  event = 'forget'  },
      { text = 'Machines',  event = 'machines'  },
      { text = 'Refresh', event = 'refresh', x = -9 },
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
  statusBar = UI.Window {
    y = -1,
    filter = UI.TextEntry {
      limit = 50,
      shadowText = 'filter',
      shadowTextColor = colors.lightGray,
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

  elseif event.type == 'machines' then
    UI:setPage('machines')

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
  self.allItems = getItems()
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter)
  self.grid:setValues(t)
end

findMachines()
loadResources()
dock()
clearGrid()
jobMonitor()

UI:setPages({
  listing = listingPage,
  machines = machinesPage,
  item = itemPage,
  learn = learnPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

Event.on('turtle_abort', function()
  UI:exitPullEvents()
end)

Event.onInterval(30, function()
  dock()
  if turtle.getFuelLevel() < 100 then
    turtle.select(1)
    inventoryAdapter:provide({ name = 'minecraft:coal', damage = 1 }, 16, 1)
    turtle.refuel()
  end
  craftItems()
end)

turtle.setStatus('idle')
UI:pullEvents()
jobListGrid.parent:reset()
