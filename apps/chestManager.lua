_G.requireInjector()

local Ansi           = require('ansi')
local ChestAdapter   = require('chestAdapter18')
local Config         = require('config')
local Craft          = require('turtle.craft')
local Event          = require('event')
local itemDB         = require('itemDB')
local MEAdapater     = require('meAdapter')
local Peripheral     = require('peripheral')
local RefinedAdapter = require('refinedAdapter')
local Terminal       = require('terminal')
local UI             = require('ui')
local Util           = require('util')

local device     = _G.device
local multishell = _ENV.multishell
local peripheral = _G.peripheral
local term       = _G.term

multishell.setTitle(multishell.getCurrent(), 'Resource Manager')

-- 3 wide monitor (any side of turtle)

-- Config location is /sys/config/chestManager
-- adjust directions in that file if needed

local config = {
  trashDirection     = 'up',    -- trash /chest in relation to chest
  inventoryDirection = { direction = 'north', wrapSide = 'back' },
  chestDirection     = { direction = 'down',  wrapSide = 'top'  },
}

Config.load('chestManager', config)

local inventoryAdapter = ChestAdapter(config.inventoryDirection)
local turtleChestAdapter = ChestAdapter(config.chestDirection)
local duckAntenna

local controller = RefinedAdapter()
if not controller:isValid() then
  controller = MEAdapater(config.inventoryDirection)
  if not controller:isValid() then
    controller = nil
  else
    inventoryAdapter = controller -- ME functions as inventory and crafting
  end
end

if device.workbench then

  local oppositeSide = {
    [ 'left'  ] = 'right',
    [ 'right' ] = 'left',
  }

  local duckAntennaSide = oppositeSide[device.workbench.side]
  duckAntenna = peripheral.wrap(duckAntennaSide)
  if not duckAntenna or not duckAntenna.getAllStacks then
    duckAntenna = nil
  end
end

local RESOURCE_FILE = 'usr/config/resources.db'
local RECIPES_FILE  = 'usr/config/recipes.db'

local colors = _G.colors
local turtle = _G.turtle

local craftingPaused = false
local canCraft = not not duckAntenna or turtleChestAdapter:isValid()
local userRecipes = Util.readTable(RECIPES_FILE) or { }
local jobListGrid
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

local function splitKey(key)
  return itemDB:splitKey(key)
end

local function getItemQuantity(items, item)
  local count = 0
  for _,v in pairs(items) do
    if v.name == item.name and
       (not item.damage or v.damage == item.damage) and
       v.nbtHash == item.nbtHash then
      if item.damage then
        return v.count
      end
      count = count + v.count
    end
  end
  return count
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

local function filterItems(t, filter, displayMode)
  if filter or displayMode > 0 then
    local r = { }
    if filter then
      filter = filter:lower()
    end
    for _,v in pairs(t) do
      if not filter or string.find(v.lname, filter) then
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

local function addCraftingRequest(item, craftList, count)
  local key = uniqueKey(item)
  local request = craftList[key]
  if not craftList[key] then
    request = { name = item.name, damage = item.damage, nbtHash = item.nbtHash, count = 0 }
    request.displayName = itemDB:getName(request)
    craftList[key] = request
  end
  request.count = request.count + count
end

local function craftItem(recipe, items, originalItem, craftList, count)

  if craftingPaused or not canCraft or not isGridClear() then
    return 0
  end

  local missing = { }
  local toCraft = Craft.getCraftableAmount(recipe, count, items, missing)
  if missing.name then
    originalItem.status = string.format('%s missing', itemDB:getName(missing.name))
    originalItem.statusCode = 'missing'
-- debug(missing.name)
  end

  if originalItem.forceCrafting and toCraft == 0 then
    for key,qty in pairs(Craft.sumIngredients(recipe)) do
      local iRecipe = Craft.recipes[key]
      if iRecipe then
        local need = count * qty
        local has = getItemQuantity(items, splitKey(key))
        if has < need then
debug('crafting ' .. key .. ' - ' .. need - has)
          craftItem(iRecipe, items, originalItem, { }, math.ceil((need - has) / iRecipe.count))
          items = inventoryAdapter:listItems()
        end
      end
    end
  end

  local crafted = 0

  if toCraft > 0 then
    crafted = Craft.craftRecipe(recipe, toCraft, inventoryAdapter)
    clearGrid()
    items = inventoryAdapter:listItems()
    count = count - crafted
  end

  if count > 0 then
    local ingredients = Craft.getResourceList(recipe, items, count)
_G._p = ingredients
    for _,ingredient in pairs(ingredients) do
      --if not ingredient.recipe and ingredient.count < 0 then
      if ingredient.count < 0 then
        addCraftingRequest(ingredient, craftList, -ingredient.count)
      end
    end
  end
  return crafted
end

local function craftItems(craftList, allItems)

  for _,key in pairs(Util.keys(craftList)) do
    local item = craftList[key]
    local recipe = Craft.recipes[key]
    if recipe then
      item.status = nil
      item.statusCode = nil
      item.crafted = craftItem(recipe, allItems, item, craftList, item.count)
      allItems = inventoryAdapter:listItems() -- refresh counts
    elseif item.rsControl then
      item.status = 'Activated'
    end
  end

  for key,item in pairs(craftList) do
    if not Craft.recipes[key] and not item.rsControl then
      if not controller then
        item.status = '(no recipe)'
      else
        if controller:isCrafting(item) then
          item.status = '(crafting)'
        else
          local count = item.count
          while count >= 1 do -- try to request smaller quantities until successful
            local s = pcall(function()
              item.status = '(no recipe)'
              if not controller:craft(item, count) then
                item.status = '(missing ingredients)'
                error('failed')
              end
              item.status = '(crafting)'
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
      { heading = 'Qty',      key = 'count',       width = 6                  },
      { heading = 'Crafting', key = 'displayName', width = mon.width / 2 - 10 },
      { heading = 'Status',   key = 'status',      width = mon.width - 10     },
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

local function getAutocraftItems()
  local craftList = { }

  for _,res in pairs(resources) do

    if res.auto then
      res.count = 64  -- this could be higher to increase autocrafting speed
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
    local item = getItemWithQty(items, res, res.ignoreDamage, res.ignoreDamage)
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
      formLabel = 'RS Control', formKey = 'rsControl',
      nochoice = 'No',
      choices = {
        { name = 'Yes', value = true },
        { name = 'No', value = false },
      },
      help = 'Control via redstone'
    },
    [6] = UI.Chooser {
      width = 25,
      formLabel = 'RS Device', formKey = 'rsDevice',
      --choices = devices,
      help = 'Redstone Device'
    },
    [7] = UI.Chooser {
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
    infoButton = UI.Button {
      x = 2, y = -2,
      event = 'show_info',
      text = 'Info',
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
    }
  },
  statusBar = UI.StatusBar { }
}

function itemPage:enable(item)
  self.item = item

  self.form:setValues(item)
  self.titleBar.title = item.displayName or item.name

  local devices = self.form[6].choices
  Util.clear(devices)
  for _,dev in pairs(device) do
    if dev.setOutput then
      table.insert(devices, { name = dev.name, value = dev.name })
    end
  end

  if Util.size(devices) == 0 then
    table.insert(devices, { name = 'None found', values = '' })
  end

  UI.Page.enable(self)
  self:focusFirst()
end

function itemPage:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'show_info' then
    self.info.textArea.value =
      string.format(
[[%sName:   %s%s
%sID:     %s%s
%sDamage: %s%s
%sNBT:    %s%s]],
Ansi.yellow, Ansi.reset, self.item.displayName,
Ansi.yellow, Ansi.reset, self.item.name,
Ansi.yellow, Ansi.reset, self.item.damage,
Ansi.yellow, Ansi.reset, self.item.nbtHash or '(none)')
    self.info:show()

  elseif event.type == 'hide_info' then
    self.info:hide()

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local values = self.form.values
    local keys = { 'name', 'auto', 'low', 'limit', 'damage',
                   'nbtHash',
                   'rsControl', 'rsDevice', 'rsSide', }

    local filtered = { }
    for _,key in pairs(keys) do
      filtered[key] = values[key]
    end
    filtered.low = tonumber(filtered.low)
    filtered.limit = tonumber(filtered.limit)

    --filtered.ignoreDamage = filtered.ignoreDamage == true
    --filtered.auto = filtered.auto == true
    --filtered.rsControl = filtered.rsControl == true

    if filtered.auto ~= true then
      filtered.auto = nil
    end

    if filtered.rsControl ~= true then
      filtered.rsControl = nil
      filtered.rsSide = nil
      filtered.rsDevice = nil
    end

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
    y = 2, height = UI.term.height - 2,
    columns = {
      { heading = 'Name', key = 'displayName' , width = 22 },
      { heading = 'Qty',  key = 'count'       , width = 5  },
      { heading = 'Min',  key = 'low'         , width = 4  },
      { heading = 'Max',  key = 'limit'       , width = 4  },
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

function listingPage.statusBar:draw()
  return UI.Window.draw(self)
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
    UI:setPage('learn')

  elseif event.type == 'craft' then
    UI:setPage('craft', self.grid:getSelected())

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
    end
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
    if canCraft and turtle.craft() then
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
            recipe.maxCount = maxCount
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

        for k,ingredient in pairs(ingredients) do
          if ingredient.maxDamage > 0 then
            ingredient.damage = '*'
          end
          ingredients[k] = uniqueKey(ingredient)
        end

        userRecipes[key] = newRecipe

        Util.writeTable(RECIPES_FILE, userRecipes)
        Craft.loadRecipes()

        local displayName = itemDB:getName(recipe)

        listingPage.statusBar.filter:setValue(displayName)
        listingPage.statusBar:timedStatus('Learned: ' .. displayName, 3)
        listingPage.filter = displayName
        listingPage:refresh()
        listingPage.grid:draw()

        return true
      end
    else
      page.statusBar:timedStatus('Failed to craft', 3)
    end
  else
    page.statusBar:timedStatus('No recipe defined', 3)
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

local craftPage = UI.Dialog {
  height = 6, width = UI.term.width - 10,
  title = 'Enter amount to craft',
  count = UI.TextEntry {
    x = 15,
    y = 3,
    width = 10,
    limit = 6,
    value = '1',
  },
  accept = UI.Button {
    x = -8, y = -2,
    backgroundColor = colors.green,
    text = '+', event = 'accept',
  },
  cancel = UI.Button {
    x = -4, y = -2,
    backgroundColor = colors.red,
    text = '\215', event = 'cancel'
  },
}

function craftPage:draw()
  UI.Dialog.draw(self)
  self:write(6, 3, 'Quantity')
end

function craftPage:enable(item)
  self.item = item
  self:focusFirst()
  UI.Dialog.enable(self)
end

function craftPage:disable()
  UI.Dialog.disable(self)
end

function craftPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()
  elseif event.type == 'accept' then
    local key = uniqueKey(self.item)
    demandCrafting[key] = Util.shallowCopy(self.item)
    demandCrafting[key].count = tonumber(self.count.value)
    demandCrafting[key].forceCrafting = true
    UI:setPreviousPage()
  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

loadResources()
clearGrid()

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
    local items = inventoryAdapter:listItems()
    if Util.size(items) == 0 then
      jobListGrid.parent:clear()
      jobListGrid.parent:centeredWrite(math.ceil(jobListGrid.parent.height/2), 'No items in system')
      jobListGrid:sync()

    else
      local craftList = watchResources(items)
      craftItems(craftList, items)

      if Util.size(demandCrafting) > 0 then
        local list = Util.shallowCopy(demandCrafting)
        craftItems(list, inventoryAdapter:listItems())
        for k,v in pairs(list) do
          craftList[k] = v
        end
      end

      jobListGrid:setValues(craftList)
      jobListGrid:update()
      jobListGrid:draw()
      jobListGrid:sync()

      for _,key in pairs(Util.keys(demandCrafting)) do
        local item = demandCrafting[key]
        item.count = item.count - item.crafted
        if item.count <= 0 then    -- should check statusCode
          demandCrafting[key] = nil
        end
      end

      craftList = getAutocraftItems(items) -- autocrafted items don't show on job monitor
      craftItems(craftList, items)
    end
  end
end)

UI:pullEvents()
jobListGrid.parent:reset()
