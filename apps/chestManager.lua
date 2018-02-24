_G.requireInjector()

local Ansi           = require('ansi')
local Config         = require('config')
local Craft          = require('turtle.craft')
local Event          = require('event')
local itemDB         = require('itemDB')
local Peripheral     = require('peripheral')
local Terminal       = require('terminal')
local UI             = require('ui')
local Util           = require('util')

local ControllerAdapter = require('controllerAdapter')
local InventoryAdapter  = require('inventoryAdapter')

local colors     = _G.colors
local device     = _G.device
local multishell = _ENV.multishell
local os         = _G.os
local term       = _G.term
local turtle     = _G.turtle

if multishell then
  multishell.setTitle(multishell.getCurrent(), 'Resource Manager')
end

local config = {
  computerFacing = 'north', -- direction turtle is facing

  inventory      = 'top',
  craftingChest  = 'bottom',
  controller     = 'none',
  stock          = 'none',

  trashDirection = 'up',    -- trash/chest in relation to inventory
  monitor        = 'type/monitor',
}

Config.loadWithCheck('inventoryManager', config)

local inventoryAdapter   = InventoryAdapter.wrap({ side = config.inventory, facing = config.computerFacing })
local turtleChestAdapter = InventoryAdapter.wrap({ side = config.craftingChest, facing = config.computerFacing })
local controllerAdapter  = ControllerAdapter.wrap({ side = config.controller, facing = config.computerFacing })
local stockAdapter       = ControllerAdapter.wrap({ side = config.stock, facing = config.computerFacing })
local duckAntenna

if not inventoryAdapter then
  error('Invalid inventory configuration')
end

if device.workbench then
  local oppositeSide = {
    [ 'left'  ] = 'right',
    [ 'right' ] = 'left',
  }
  local duckAntennaSide = oppositeSide[device.workbench.side]
  if Peripheral.getType(duckAntennaSide) == os.getComputerLabel() then
    duckAntenna = Peripheral.wrap(duckAntennaSide)
    if duckAntenna and not duckAntenna.getAllStacks then
      duckAntenna = nil
    end
  end
end

local STATUS_INFO    = 'info'
local STATUS_WARNING = 'warning'
local STATUS_ERROR   = 'error'

local RESOURCE_FILE = 'usr/config/resources.db'
local RECIPES_FILE  = 'usr/config/recipes.db'

local craftingPaused = false
local canCraft = not not (turtle and turtle.craft)
local canLearn = not not (canCraft and (duckAntenna or turtleChestAdapter))
local userRecipes = Util.readTable(RECIPES_FILE) or { }
local jobList
local resources
local demandCrafting = { }

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

  for k in pairs(Craft.recipes) do
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

local function listItems()
  local items
  for _ = 1, 5 do
    items = inventoryAdapter:listItems()
    if items then
      break
    end
    os.sleep(.25)
  end
  if not items then
--    error('could not check inventory')
term.clear()
print('Communication failure')
print('rebooting in 5 secs')
os.sleep(5)
os.reboot()
  end

  return items
end

local function filterItems(t, filter, displayMode)
  if filter or displayMode > 0 then
    local r = { }
    if filter then
      filter = filter:lower()
    end
    for _,v in pairs(t) do
      if not filter or string.find(v.lname, filter, 1, true) then
        if not displayMode or
          displayMode == 0 or
          displayMode == 1 and v.count > 0 or
          displayMode == 2 and v.has_recipe then
          table.insert(r, v)
        end
      end
    end
    return r
  end
  return t
end

local function isGridClear()
  for i = 1, 16 do
    if turtle.getItemCount(i) ~= 0 then
      return false
    end
  end
  return true
end

local function clearGrid()
  local function clear()
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
  return clear() or clear()
end

local function addCraftingRequest(item, craftList, count)
  local key = uniqueKey(item)
  local request = craftList[key]
  if not craftList[key] then
    request = { name = item.name, damage = item.damage, nbtHash = item.nbtHash, count = 0 }
    request.displayName = itemDB:getName(request)
    craftList[key] = request
  end
  request.count = request.count + count
  return request
end

local function craftItem(recipe, items, originalItem, craftList, count)

  if craftingPaused or not canCraft then
    return 0
  end

  if not isGridClear() then
    if not clearGrid() then
      originalItem.status = 'Grid obstructed'
      originalItem.statusCode = STATUS_ERROR
      return 0
    end
  end

  local missing = { }
  local toCraft = Craft.getCraftableAmount(recipe, count, items, missing)
  if missing.name then
    originalItem.status = string.format('%s missing', itemDB:getName(missing.name))
    originalItem.statusCode = STATUS_WARNING
  end

  local crafted = 0

  if toCraft > 0 then
    crafted = Craft.craftRecipe(recipe, toCraft, inventoryAdapter)
    clearGrid()
    items = listItems()
    count = count - crafted
  end

  if count > 0 and items then
    local ingredients = Craft.getResourceList4(recipe, items, count)
    for _,ingredient in pairs(ingredients) do
      if ingredient.need > 0 then
        local item = addCraftingRequest(ingredient, craftList, ingredient.need)
        if Craft.findRecipe(item) then
          item.status = string.format('%s missing', itemDB:getName(ingredient))
          item.statusCode = STATUS_WARNING
        else
          item.status = 'no recipe'
          item.statusCode = STATUS_ERROR
        end
      end
    end
  end
  return crafted
end

local function forceCraftItem(inRecipe, items, originalItem, craftList, inCount)
  local summed = { }
  local throttle = Util.throttle()

  local function sumItems(recipe, count)
    count = math.ceil(count / recipe.count)
    local craftable = count

    for key,iqty in pairs(Craft.sumIngredients(recipe)) do
      throttle()
      local item = itemDB:splitKey(key)
      local summedItem = summed[key]
      if not summedItem then
        summedItem = Util.shallowCopy(item)
        summedItem.recipe = Craft.findRecipe(item)
        summedItem.count = Craft.getItemCount(items, key)
        summedItem.need = 0
        summedItem.used = 0
        summedItem.craftable = 0
        summed[key] = summedItem
      end

      local total = count * iqty                           -- 4 * 2
      local used = math.min(summedItem.count, total)       -- 5
      local need = total - used                            -- 3

      if recipe.craftingTools and recipe.craftingTools[key] then
        if summedItem.count > 0 then
          summedItem.used = 1
          need = 0
        else
          summedItem.need = 1
          need = 1
        end
      else
        summedItem.count = summedItem.count - used
        summedItem.used = summedItem.used + used
      end

      if need > 0 then
        if not summedItem.recipe then
          craftable = math.min(craftable, math.floor(used / iqty))
          summedItem.need = summedItem.need + need
        else
          local c = sumItems(summedItem.recipe, need) -- 4
          craftable = math.min(craftable, math.floor((used + c) / iqty))
          summedItem.craftable = summedItem.craftable + c
        end
      end
    end
    if craftable > 0 then
      craftable = Craft.craftRecipe(recipe, craftable * recipe.count, inventoryAdapter) / recipe.count
      clearGrid()
    end

    return craftable * recipe.count
  end

  local count = sumItems(inRecipe, inCount)

--  local count, summed = Craft.getResourceList3(inRecipe, items, inCount, inventoryAdapter)
  if count < inCount then
    for _,ingredient in pairs(summed) do
      if ingredient.need > 0 then
        local item = addCraftingRequest(ingredient, craftList, ingredient.need)
        if Craft.findRecipe(item) then
          item.status = string.format('%s missing', itemDB:getName(ingredient))
          item.statusCode = STATUS_WARNING
        else
          item.status = '(no recipe)'
          item.statusCode = STATUS_ERROR
        end
      end
    end
  end
  return count
end

local function craftItems(craftList, allItems)
  -- turtle crafting
  if canCraft then
    for _,key in pairs(Util.keys(craftList)) do
      local item = craftList[key]
      local recipe = Craft.recipes[key]
      if recipe then
        item.status = nil
        item.statusCode = nil
        if item.forceCrafting then
          item.crafted = forceCraftItem(recipe, allItems, item, craftList, item.count)
        else
          item.crafted = craftItem(recipe, allItems, item, craftList, item.count)
        end
        allItems = listItems() -- refresh counts
        if not allItems then
          break
        end
      elseif not controllerAdapter then
        item.status = '(no recipe)'
        item.statusCode = STATUS_ERROR
      end
    end
  end

  -- redstone control
  for _,item in pairs(craftList) do
    if item.rsControl then
      item.status = '(activated)'
      item.statusCode = STATUS_INFO
    end
  end

  -- controller
  if controllerAdapter then
    for key,item in pairs(craftList) do
      if not Craft.recipes[key] and not item.rsControl then
        if controllerAdapter:isCrafting(item) then
          item.status = '(crafting)'
          item.statusCode = STATUS_INFO
        else
          local count = item.count
          while count >= 1 do -- try to request smaller quantities until successful
            local s = pcall(function()
              item.status = '(no recipe)'
              item.statusCode = STATUS_ERROR
              if not controllerAdapter:craft(item, count) then
                item.status = '(missing ingredients)'
                item.statusCode = STATUS_WARNING
                error('failed')
              end
              item.status = '(crafting)'
              item.statusCode = STATUS_INFO
            end)
            if s then
              break -- successfully requested crafting
            end
            count = math.floor(count / 2)
          end
        end
      end
    end
  end

  if not controllerAdapter and not canCraft then
    for _,item in pairs(craftList) do
      if not item.rsControl then
        item.status = 'Invalid setup'
        item.statusCode = STATUS_INFO
      end
    end
  end
end

local function restock()
  if turtle and stockAdapter:isValid() then
    local items = inventoryAdapter:listItems()
    local stock = stockAdapter:listItems()

    if items and stock then
      for _,v in pairs(stock) do
        local count = Craft.getItemCount(items, v)
        if count < 64 then
          count = 64 - count
          stockAdapter:provide(v, count)
          clearGrid()
        end
      end
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

  jobList = UI.Page {
    parent = mon,
    grid = UI.Grid {
      sortColumn = 'displayName',
      columns = {
        { heading = 'Qty',      key = 'count',       width = 6                  },
        { heading = 'Crafting', key = 'displayName', width = mon.width / 2 - 10 },
        { heading = 'Status',   key = 'status',      width = mon.width - 10     },
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
    if row.statusCode == STATUS_ERROR then
      return colors.red
    elseif row.statusCode == STATUS_WARNING then
      return colors.yellow
    elseif row.statusCode == STATUS_INFO then
      return colors.lime
    end
    return UI.Grid:getRowTextColor(row, selected)
  end

  jobList:enable()
  jobList:draw()
  jobList:sync()
end

local function getAutocraftItems()
  local craftList = { }

  for _,res in pairs(resources) do

    if res.auto then
      res.count = 256  -- this could be higher to increase autocrafting speed
      local key = uniqueKey(res)
      craftList[key] = res
    end
  end
  return craftList
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

local function watchResources(items)

  local craftList = { }
  local outputs   = { }

  for _,res in pairs(resources) do
    local item = getItemWithQty(items, res, res.ignoreDamage, res.ignoreNbtHash)
    if not item then
      item = {
        damage = res.damage,
        nbtHash = res.nbtHash,
        name = res.name,
        displayName = itemDB:getName(res),
        count = 0
      }
    end

    if res.limit and item.count > res.limit then
      inventoryAdapter:provide(
        { name = item.name, damage = item.damage, nbtHash = item.nbtHash },
        item.count - res.limit,
        nil,
        config.trashDirection)

    elseif res.low and item.count < res.low then
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
        rsControl = res.rsControl,
      }
    end

    if res.rsControl and res.rsDevice and res.rsSide then
      local enable = item.count < res.low
      if not outputs[res.rsDevice] then
        outputs[res.rsDevice] = { }
      end
      outputs[res.rsDevice][res.rsSide] = outputs[res.rsDevice][res.rsSide] or enable
    end
  end

  for rsDevice, sides in pairs(outputs) do
    for side, enable in pairs(sides) do
      pcall(function()
        device[rsDevice].setOutput(side, enable)
      end)
    end
  end

  return craftList
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
    local keys = Util.transpose({ 'auto', 'low', 'limit',
                  'ignoreDamage', 'ignoreNbtHash',
                   'rsControl', 'rsDevice', 'rsSide' })

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
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min'
    },
    [2] = UI.TextEntry {
      width = 7,
      formLabel = 'Max', formKey = 'limit', help = 'Eject if above max'
    },
    [3] = UI.Chooser {
      width = 7,
      formLabel = 'Autocraft', formKey = 'auto',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Craft until out of ingredients'
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
--[[
    [6] = UI.Button {
      x = 2, y = -2, width = 10,
      formLabel = 'Redstone',
      event = 'show_rs',
      text = 'Configure',
    },
]]
    infoButton = UI.Button {
      x = 2, y = -2,
      event = 'show_info',
      text = 'Info',
    },
  },
  rsControl = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = "Redstone Control",
    },
    form = UI.Form {
      y = 2,
      [1] = UI.Chooser {
        width = 7,
        formLabel = 'RS Control', formKey = 'rsControl',
        nochoice = 'No',
        choices = {
          { name = 'Yes', value = true },
          { name = 'No', value = false },
        },
        help = 'Control via redstone'
      },
      [2] = UI.Chooser {
        width = 25,
        formLabel = 'RS Device', formKey = 'rsDevice',
        --choices = devices,
        help = 'Redstone Device'
      },
      [3] = UI.Chooser {
        width = 10,
        formLabel = 'RS Side', formKey = 'rsSide',
        --nochoice = 'No',
        choices = {
          { name = 'up', value = 'up' },
          { name = 'down', value = 'down' },
          { name = 'east', value = 'east' },
          { name = 'north', value = 'north' },
          { name = 'west', value = 'west' },
          { name = 'south', value = 'south' },
        },
        help = 'Output side'
      },
    },
  },
  info = UI.SlideOut {
    titleBar = UI.TitleBar {
      title = "Information",
    },
    textArea = UI.TextArea {
      x = 2, ex = -2, y = 3, ey = -4,
      backgroundColor = colors.black,
    },
    cancel = UI.Button {
      ex = -2, y = -2, width = 6,
      text = 'Okay',
      event = 'hide_info',
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

function itemPage.rsControl:enable()
  local devices = self.form[1].choices
  Util.clear(devices)
  for _,dev in pairs(device) do
    if dev.setOutput then
      table.insert(devices, { name = dev.name, value = dev.name })
    end
  end

  if Util.size(devices) == 0 then
    table.insert(devices, { name = 'None found', values = '' })
  end

  UI.SlideOut.enable(self)
end

function itemPage.rsControl:eventHandler(event)
  if event.type == 'form_cancel' then
    self:hide()
  elseif event.type == 'form_complete' then
    self:hide()
  else
    return UI.SlideOut.eventHandler(self, event)
  end
  return true
end

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'show_rs' then
    self.rsControl:show()

  elseif event.type == 'show_info' then
    local value =
      string.format('%s%s%s\n%s\n',
        Ansi.orange, self.item.displayName, Ansi.reset,
        self.item.name)

    if self.item.nbtHash then
      value = value .. self.item.nbtHash .. '\n'
    end

    value = value .. string.format('\n%sDamage:%s %s',
      Ansi.yellow, Ansi.reset, self.item.damage)

    if self.item.maxDamage and self.item.maxDamage > 0 then
      value = value .. string.format(' (max: %s)', self.item.maxDamage)
    end

    if self.item.maxCount then
      value = value .. string.format('\n%sStack Size: %s%s',
        Ansi.yellow, Ansi.reset, self.item.maxCount)
    end

    self.info.textArea.value = value
    self.info:show()

  elseif event.type == 'hide_info' then
    self.info:hide()

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local values = self.form.values
    local originalKey = uniqueKey(self.item)

    local filtered = Util.shallowCopy(values)
    filtered.low = tonumber(filtered.low)
    filtered.limit = tonumber(filtered.limit)

    if filtered.auto ~= true then
      filtered.auto = nil
    end

    if filtered.rsControl ~= true then
      filtered.rsControl = nil
      filtered.rsSide = nil
      filtered.rsDevice = nil
    end

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
    resources[originalKey] = nil
    resources[uniqueKey(filtered)] = filtered

    filtered.count = nil
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
      { text = 'Learn',   event = 'learn'   },
      { text = 'Forget',  event = 'forget'  },
      { text = 'Craft',   event = 'craft'   },
      { text = 'Refresh', event = 'refresh', x = -9 },
    },
  },
  grid = UI.Grid {
    y = 2, ey = -2,
    columns = {
      { heading = 'Name', key = 'displayName' },
      { heading = 'Qty',  key = 'count'       , width = 4 },
      { heading = 'Min',  key = 'low'         , width = 4 },
      { heading = 'Max',  key = 'limit'       , width = 4 },
    },
    sortColumn = 'displayName',
  },
  statusBar = UI.StatusBar {
    filter = UI.TextEntry {
      x = 1, ex = -4,
      limit = 50,
      shadowText = 'filter',
      shadowTextColor = colors.gray,
      backgroundColor = colors.cyan,
      backgroundFocusColor = colors.cyan,
    },
    display = UI.Button {
      x = -3,
      event = 'toggle_display',
      value = 0,
      text = 'A',
    },
  },
  notification = UI.Notification(),
  accelerators = {
    r = 'refresh',
    q = 'quit',
    grid_select_right = 'craft',
  },
  displayMode = 0,
}

function listingPage.statusBar:draw()
  return UI.Window.draw(self)
end

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

  elseif event.type == 'learn' then
    if canLearn then
      UI:setPage('learn')
    else
      self.notification:error('Missing a crafting chest or workbench\nCheck configuration')
    end

  elseif event.type == 'craft' or event.type == 'grid_select_right' then
    if Craft.findRecipe(self.grid:getSelected()) then
      UI:setPage('craft', self.grid:getSelected())
    else
      self.notification:error('No recipe defined')
    end

  elseif event.type == 'forget' then
    local item = self.grid:getSelected()
    if item then
      local key = uniqueKey(item)

      if userRecipes[key] then
        userRecipes[key] = nil
        Util.writeTable(RECIPES_FILE, userRecipes)
        Craft.loadRecipes()
      end

      if resources[key] then
        resources[key] = nil
        saveResources()
      end

      self.notification:info('Forgot: ' .. item.name)
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
  self.allItems = listItems()
  mergeResources(self.allItems)
  self:applyFilter()
end

function listingPage:applyFilter()
  local t = filterItems(self.allItems, self.filter, self.displayMode)
  self.grid:setValues(t)
end

local function getTurtleInventory()
  if duckAntenna then
    local list = duckAntenna.getAllStacks(false)
    for _,v in pairs(list) do
      v.name = v.id
      v.damage = v.dmg
      v.displayName = v.display_name
      v.count = v.qty
      v.maxDamage = v.max_dmg
      v.maxCount = v.max_size
      if not itemDB:get(v) then
        itemDB:add(v)
      end
    end
    itemDB:flush()
    return list
  end

  local inventory = { }
  for i = 1,16 do
    local qty = turtle.getItemCount(i)
    if qty > 0 then
      turtleChestAdapter:insert(i, qty)
      local items = turtleChestAdapter:listItems()
      _, inventory[i] = next(items)
      turtleChestAdapter:extract(1, qty, i)
    end
  end
  return inventory
end

local function learnRecipe(page)
  local ingredients = getTurtleInventory()
  if ingredients then
    turtle.select(1)
    if canLearn and turtle.craft() then
      local results = getTurtleInventory()
      if results and results[1] then
        clearGrid()

        local maxCount
        local newRecipe = {
          ingredients = ingredients,
        }

        for _,v1 in pairs(results) do
          for _,v2 in pairs(ingredients) do
            if v1.name == v2.name and
              v1.nbtHash == v2.nbtHash and
              (v1.damage == v2.damage or
                (v1.maxDamage > 0 and v2.maxDamage > 0 and
                 v1.damage ~= v2.damage)) then
              if not newRecipe.crafingTools then
                newRecipe.craftingTools = { }
              end
              local tool = Util.shallowCopy(v2)
              if tool.maxDamage > 0 then
                tool.damage = '*'
              end

              --[[
              Turtles can only craft one item at a time using a tool :(
              ]]--
              maxCount = 1

              newRecipe.craftingTools[uniqueKey(tool)] = true
              v1.craftingTool = true
              break
            end
          end
        end
        local recipe
        for _,v in pairs(results) do
          if not v.craftingTool then
            recipe = v
            if maxCount then
              recipe.maxCount = maxCount
            end
            break
          end
        end

        if not recipe then
          error('Failed')
        end

        newRecipe.count = recipe.count

        local key = uniqueKey(recipe)
        if recipe.maxCount ~= 64 then
          newRecipe.maxCount = recipe.maxCount
        end
        for k,ingredient in pairs(Util.shallowCopy(ingredients)) do
          if ingredient.maxDamage > 0 then
            ingredient.damage = '*'               -- I don't think this is right
          end
          ingredients[k] = uniqueKey(ingredient)
        end

        userRecipes[key] = newRecipe

        Util.writeTable(RECIPES_FILE, userRecipes)
        Craft.loadRecipes()

        local displayName = itemDB:getName(recipe)

        listingPage.statusBar.filter:setValue(displayName)
        listingPage.notification:success('Learned: ' .. displayName)
        listingPage.filter = displayName
        listingPage:refresh()
        listingPage.grid:draw()

        inventoryAdapter:eject(recipe, recipe.count, 'front')
        return true
      end
    else
      listingPage.notification:error('Failed to craft', 3)
    end
  else
    listingPage.notification:error('No recipe defined', 3)
  end
end

local learnPage = UI.Dialog {
  height = 7, width = UI.term.width - 6,
  title = 'Learn Recipe',
  idField = UI.Text {
    x = 5,
    y = 3,
    width = UI.term.width - 10,
    value = 'Place recipe in turtle'
  },
  accept = UI.Button {
    x = -14, y = -3,
    text = 'Ok', event = 'accept',
  },
  cancel = UI.Button {
    x = -9, y = -3,
    text = 'Cancel', event = 'cancel'
  },
  statusBar = UI.StatusBar {
    status = 'Crafting paused'
  }
}

function learnPage:enable()
  craftingPaused = true
  self:focusFirst()
  UI.Dialog.enable(self)
end

function learnPage:disable()
  craftingPaused = false
  UI.Dialog.disable(self)
end

function learnPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()
  elseif event.type == 'accept' then
    if learnRecipe(self) then
      UI:setPreviousPage()
    end
  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

local craftPage = UI.Page {
  titleBar = UI.TitleBar { },
  wizard = UI.Wizard {
    y = 2, ey = -2,
    pages = {
      quantity = UI.Window {
        index = 1,
        text = UI.Text {
          x = 6, y = 3,
          value = 'Quantity',
        },
        count = UI.TextEntry {
          x = 15, y = 3, width = 10,
          limit = 6,
          value = 1,
        },
        ejectText = UI.Text {
          x = 6, y = 4,
          value = 'Eject',
        },
        eject = UI.Chooser {
          x = 15, y = 4, width = 7,
          value = true,
          nochoice = 'No',
          choices = {
            { name = 'Yes', value = true },
            { name = 'No', value = false },
          },
        },
      },
      resources = UI.Window {
        index = 2,
        grid = UI.ScrollingGrid {
          y = 2, ey = -2,
          columns = {
            { heading = 'Name',  key = 'displayName' },
            { heading = 'Total', key = 'total'      , width = 5 },
            { heading = 'Used',  key = 'used'       , width = 5 },
            { heading = 'Need',  key = 'need'       , width = 5 },
          },
          sortColumn = 'displayName',
        },
      },
    },
  },
}

function craftPage:enable(item)
  self.item = item
  self:focusFirst()
  self.titleBar.title = itemDB:getName(item)
--  self.wizard.pages.quantity.eject.value = true
  UI.Page.enable(self)
end

function craftPage.wizard.pages.resources.grid:getDisplayValues(row)
  local function dv(v)
    if v == 0 then
      return ''
    end
    return Util.toBytes(v)
  end
  row = Util.shallowCopy(row)
  row.total = Util.toBytes(row.total)
  row.used = dv(row.used)
  row.need = dv(row.need)
  return row
end

function craftPage.wizard.pages.resources.grid:getRowTextColor(row, selected)
  if row.need > 0 then
    return colors.orange
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function craftPage.wizard:eventHandler(event)
  if event.type == 'nextView' then
    local count = tonumber(self.pages.quantity.count.value)
    if not count or count <= 0 then
      self.pages.quantity.count.backgroundColor = colors.red
      self.pages.quantity.count:draw()
      return false
    end
    self.pages.quantity.count.backgroundColor = colors.black
  end
  return UI.Wizard.eventHandler(self, event)
end

function craftPage.wizard.pages.resources:enable()
  local items = listItems()
  local count = tonumber(self.parent.quantity.count.value)
  local recipe = Craft.findRecipe(craftPage.item)
  local ingredients = Craft.getResourceList4(recipe, items, count)
  for _,v in pairs(ingredients) do
    v.displayName = itemDB:getName(v)
  end
  self.grid:setValues(ingredients)
  return UI.Window.enable(self)
end

function craftPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()

  elseif event.type == 'accept' then
    local key = uniqueKey(self.item)
    demandCrafting[key] = Util.shallowCopy(self.item)
    demandCrafting[key].count = tonumber(self.wizard.pages.quantity.count.value)
    demandCrafting[key].ocount = demandCrafting[key].count
    demandCrafting[key].forceCrafting = true
    demandCrafting[key].eject = self.wizard.pages.quantity.eject.value == true
    UI:setPreviousPage()
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

loadResources()
if canCraft then
  clearGrid()
end

UI:setPages({
  listing = listingPage,
  item = itemPage,
  learn = learnPage,
  craft = craftPage,
})

UI:setPage(listingPage)
listingPage:setFocus(listingPage.statusBar.filter)

jobMonitor()

Event.onInterval(5, function()

  if not craftingPaused then
    local items = listItems()
    if not items or Util.size(items) == 0 then
      jobList:showError('No items in system')
    else
      local demandCrafted
      if Util.size(demandCrafting) > 0 then
        items = listItems()
        if items then
          demandCrafted = Util.shallowCopy(demandCrafting)
          craftItems(demandCrafted, items)
        end
      end

      items = listItems()
      local craftList
      if items then
        craftList = watchResources(items)
        craftItems(craftList, items)
      end

      if demandCrafted and craftList then
        for k,v in pairs(demandCrafted) do
          craftList[k] = v
        end
      end

      for _,key in pairs(Util.keys(demandCrafting)) do
        local item = demandCrafting[key]
        if item.crafted then
          item.count = math.max(0, item.count - item.crafted)
          if item.count <= 0 then
            demandCrafting[key] = nil
            item.statusCode = 'success'
            if item.eject then
              inventoryAdapter:eject(item, item.ocount, 'front')
            end
          end
        end
      end

      jobList:updateList(craftList)

      craftList = getAutocraftItems(items) -- autocrafted items don't show on job monitor
      craftItems(craftList, items)

      restock()
    end
  end
end)

UI:pullEvents()
jobList.parent:reset()
