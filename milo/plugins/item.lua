local Ansi   = require('ansi')
local Craft  = require('craft2')
local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors

local context = Milo:getContext()

local manageTab = UI.Window {
  tabTitle = 'Manage',
  form = UI.Form {
    x = 1, ex = -1, ey = -1,
    --manualControls = true,
    [1] = UI.TextEntry {
      formLabel = 'Name', formKey = 'displayName', help = 'Override display name',
      shadowText = 'Display name',
      required = true,
      limit = 120,
    },
    [2] = UI.TextEntry {
      width = 7,
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min',
      validate = 'numeric',
    },
    [3] = UI.TextEntry {
      width = 7,
      formLabel = 'Max', formKey = 'limit', help = 'Send to trash if above max',
      validate = 'numeric',
    },
    [4] = UI.Checkbox {
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      help = 'Ignore damage of item',
    },
    [5] = UI.Checkbox {
      formLabel = 'Ignore NBT', formKey = 'ignoreNbtHash',
      help = 'Ignore NBT of item',
    },
  },
}

local machinesTab = UI.Window {
  tabTitle = 'Machine',
  backgroundColor = colors.cyan,
  grid = UI.ScrollingGrid {
    x = 2, ex = -2, y = 2, ey = -2,
    disableHeader = true,
    columns = {
      { heading = 'Name', key = 'displayName'},
    },
    sortColumn = 'displayName',
    help = 'Double-click to set machine',
  },
}

local recipeTab = UI.Window {
  tabTitle = 'Recipe',
  backgroundColor = colors.cyan,
  grid = UI.ScrollingGrid {
    x = 2, ex = -2, y = 2, ey = -4,
    disableHeader = true,
    columns = {
      { heading = 'Slot', key = 'slot', width = 2 },
      { heading = 'Key', key = 'key' },
    },
    sortColumn = 'slot',
  },
  ignoreNBT = UI.Button {
    x = -13, y = -2,
    text = 'Ignore NBT', event = 'ignore_nbt',
  },
}

local infoTab = UI.Window {
  tabTitle = 'Info',
  backgroundColor = colors.cyan,
  textArea = UI.TextArea {
    x = 2, ex = -2, y = 2,
  },
}

local resetTab = UI.Window {
  tabTitle = 'Reset',
  backgroundColor = colors.cyan,
  textArea = UI.TextArea {
    y = 2, ey = 6,
    textColor = colors.yellow,
    value = [[                Warning!

    This will clear all setting,
  recipe, and machine for this item.]]
  },
  resetButton = UI.Button {
    x = 17, y = 7,
    event = 'reset',
    text = 'Reset',
    help = 'Clear recipe and all settings',
  },
}

local page = UI.Page {
  titleBar = UI.TitleBar {
    title = 'Item settings',
    previousPage = true,
  },
  tabs = UI.Tabs {
    y = 2, ey = -2,
    [1] = manageTab,
    [2] = recipeTab,
    [3] = machinesTab,
    [4] = infoTab,
    [5] = resetTab,
  },
  statusBar = UI.StatusBar { },
  notification = UI.Notification { },
}

function page:enable(item)
  self.origItem = item
  self.item = Util.shallowCopy(item)
  self.res = item.resource or { }
  self.res.displayName = self.item.displayName
  manageTab.form:setValues(self.res)

  local machine = Craft.machineLookup[self.item.key]
  if machine then
    self:filterMachines(machine)
  end

  self.tabs:selectTab(manageTab)

  self.tabs:setActive(machinesTab, machine)
  self.tabs:setActive(recipeTab, Craft.findRecipe(item))

  UI.Page.enable(self)
end

function page:filterMachines(machine)
  local t = Util.filter(context.storage.nodes, function(node)
    if node.category == 'machine' or node.category == 'custom' then -- TODO: - need a setting instead (ie. canCraft)
      return node.adapter and node.adapter.online and node.adapter.pushItems
    end
  end)
  machinesTab.grid:setValues(t)
  machinesTab.grid:setSelected('name', machine)
end

function machinesTab.grid:getDisplayValues(row)
  row = Util.shallowCopy(row)
  row.displayName = row.displayName or row.name
  return row
end

function machinesTab.grid:getRowTextColor(row, selected)
  if row.name == Craft.machineLookup[page.item.key] then
    return colors.yellow
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function machinesTab:eventHandler(event)
  if event.type == 'grid_select' then
    Craft.machineLookup[page.item.key] = event.selected.name
    Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)

    self.grid:draw()
    page.notification:info('Machine saved')

    return true
  end
end

function recipeTab:enable()
  self.recipe = Craft.findRecipe(page.item)

  local t = { }
  if self.recipe then
    for k, v in pairs(self.recipe.ingredients) do
      table.insert(t, {
        slot = k,
        key = v,
      })
    end
  end
  self.grid:setValues(t)
  UI.Window.enable(self)
end

function recipeTab:eventHandler(event)
  if event.type == 'ignore_nbt' then
    local selected = self.grid:getSelected()
    local item = itemDB:splitKey(selected.key)
    item.nbtHash = nil
    selected.key = itemDB:makeKey(item)
    self.grid:draw()

    self.recipe.ingredients = { }
    for _, v in pairs(self.grid.values) do
      self.recipe.ingredients[v.slot] = v.key
    end

    Milo:updateRecipe(self.recipe.result, self.recipe)
    page.notification:info('Recipe updated')

    return true
  end
end

function infoTab:draw()
  local item = page.item
  local value =
    string.format('%s%s%s\n%s\n',
      Ansi.orange, item.displayName, Ansi.reset,
      item.name)

  if item.nbtHash then
    value = value .. item.nbtHash .. '\n'
  end

  value = value .. string.format('\n%sDamage:%s %s',
    Ansi.yellow, Ansi.reset, item.damage)

  if item.maxDamage and item.maxDamage > 0 then
    value = value .. string.format(' (max: %s)', item.maxDamage)
  end

  if item.maxCount then
    value = value .. string.format('\n%sStack Size: %s%s',
      Ansi.yellow, Ansi.reset, item.maxCount)
  end

  self.textArea.value = value
  UI.Window.draw(self)
end

function page:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'reset' then
    if context.userRecipes[self.item.key] then
      Milo:updateRecipe(self.item.key, nil)
    end

    if context.resources[self.item.key] then
      context.resources[self.item.key] = nil
      Milo:saveResources()
    end

    if Craft.machineLookup[self.item.key] then
      Craft.machineLookup[self.item.key] = nil
      Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)
    end

    UI:setPreviousPage()

  elseif event.type == 'tab_activate' then
    event.activated:focusFirst()

  elseif event.type == 'form_invalid' then
    self.notification:error(event.message)

  elseif event.type == 'focus_change' then
    self.statusBar:setStatus(event.focused.help)
    self.statusBar:draw()

  elseif event.type == 'form_complete' then
    local item = self.item

    if manageTab.form:save() then
      if self.res.displayName ~= self.origItem.displayName then
        self.origItem.displayName = self.res.displayName
        itemDB:add(self.origItem)
        itemDB:flush()

        -- TODO: ugh
        if context.storage.cache[self.origItem.key] then
          context.storage.cache[self.origItem.key].displayName = self.res.displayName
        end
      end
      self.res.displayName = nil
      Util.prune(self.res, function(v)
        if type(v) == 'boolean' then
          return v
        elseif type(v) == 'string' then
          return #v > 0
        end
        return true
      end)

      local newKey = {
        name = item.name,
        damage = self.res.ignoreDamage and 0 or item.damage,
        nbtHash = not self.res.ignoreNbtHash and item.nbtHash or nil,
      }

      for k,v in pairs(context.resources) do
        if v == self.res then
          context.resources[k] = nil
          break
        end
      end

      if not Util.empty(self.res) then
        context.resources[Milo:uniqueKey(newKey)] = self.res
      end

      Milo:saveResources()
      UI:setPreviousPage()
    end
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

UI:addPage('item', page)
