--[[
  Provides: autocrafting, resource limits, on-demand crafting, storage stocker.

  Using a turtle allows for crafting of items eliminating the need for AE/RS
  molecular assemblers / crafters.

  Inventory setup:
    Turtle/computer must be touching at least one type of inventory

    Generic inventory block such as:
      Vanilla chest
      RFTools modular storage
      Storage drawers controller
      and many others...

    Applied energistics
      AE cable or interface (depending upon AE/MC version)

    Refined storage
      TODO: add required block

  Turtle crafting:
    1. The turtle must have a crafting table equipped.
    2. Equip the turtle with an introspection module.

  Controller (optional):
    Provides the ability to request crafting from AE / RS

    Applied Energistics
      In versions 1.7x, AE can be used for both inventory access and crafting
      requests.

      In versions 1.8+, AE can only be used to request crafting.

    Refined Storage
      In versions 1.8x, inventory access works depending upon version.

      Turtle/computer must be touching an interface for inventory access. If only
      requesting crafting, the controller must be either be touching or connected
      via CC cables.

  Configuration:
    Configuration file is usr/config/inventoryManager

    monitor        : valid options include:
                     type/monitor   - will use the first monitor found
                     side/north     - specify a direction (top/bottom/east/etc)
                     name/monitor_1 - specify the exact name of the peripheral
]]--

--[[
limit
organize
replenish
autocraft
]]

_G.requireInjector()

local Config         = require('config')
local Event          = require('event')
local itemDB         = require('itemDB')
local Lora           = require('lora/lora')
local Peripheral     = require('peripheral')
local UI             = require('ui')
local Util           = require('util')

local InventoryAdapter  = require('inventoryAdapter')

local fs         = _G.fs
local multishell = _ENV.multishell
local shell      = _ENV.shell

if multishell then
  multishell.setTitle(multishell.getCurrent(), 'Resource Manager')
end

local config = {
  monitor = 'type/monitor',
  remoteDefaults = { },
}
Config.load('inventoryManager', config)

local modem = Peripheral.get('wired_modem')
if not modem or not modem.getNameLocal then
  error('Wired modem is not connected')
end

local storage = { }
for k,v in pairs(config.remoteDefaults) do
  if v.mtype == 'storage' then
    storage[k] = v
  elseif v.mtype == 'controller' then
    -- TODO: look for controller
  end
end

local inventoryAdapter = InventoryAdapter.wrap({ remoteDefaults = storage })
if not inventoryAdapter then
  error('Invalid inventory configuration')
end

-- TODO: cleanup
for _, v in pairs(modem.getNamesRemote()) do
  local remote = Peripheral.get({ name = v })
  if remote.pullItems then
    if not config.remoteDefaults[v] then
      config.remoteDefaults[v] = {
        name  = v,
        mtype = 'ignore',
      }
    else
      config.remoteDefaults[v].name = v
    end
    if not config.remoteDefaults[v].mtype then
      config.remoteDefaults[v].mtype = 'ignore'
    end
  end
end

local function loadResources()
  local resources = Util.readTable(Lora.RESOURCE_FILE) or { }
  for k,v in pairs(resources) do
    Util.merge(v, itemDB:splitKey(k))
  end

  return resources
end

local context = {
  config = config,
  inventoryAdapter = inventoryAdapter,
  resources = loadResources(),
  userRecipes = Util.readTable(Lora.RECIPES_FILE) or { },
}

Lora:init(context)

local programDir = fs.getDir(shell.getRunningProgram())
local pluginDir = fs.combine(programDir, 'plugins')

for _, file in pairs(fs.list(pluginDir)) do
  local s, m = Util.run(_ENV, fs.combine(pluginDir, file))
  if not s and m then
    error(m or 'Unknown error')
  end
end

table.sort(Lora.tasks, function(a, b)
  return a.priority < b.priority
end)

Lora:clearGrid()

local page = UI:getPage('listing')
UI:setPage(page)
page:setFocus(page.statusBar.filter)

Event.onInterval(5, function()
  if not Lora:isCraftingPaused() then
    Lora:resetCraftingStatus()
    context.inventoryAdapter:refresh()

    for _, task in ipairs(Lora.tasks) do
      task:cycle(context)
    end
  end
end)

UI:pullEvents()
