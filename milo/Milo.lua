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
    Configuration file is usr/config/milo

    monitor        : valid options include:
                     type/monitor   - will use the first monitor found
                     side/north     - specify a direction (top/bottom/east/etc)
                     name/monitor_1 - specify the exact name of the peripheral



  -- Internal
  Imports are at < 20

]]--

--[[
limit
organize
replenish
autocraft
]]

_G.requireInjector(_ENV)

local Config         = require('config')
local Event          = require('event')
local itemDB         = require('itemDB')
local Milo           = require('milo')
local NetworkAdapter = require('networkedAdapter18')
local Peripheral     = require('peripheral')
local UI             = require('ui')
local Util           = require('util')

local device     = _G.device
local fs         = _G.fs
local multishell = _ENV.multishell
local shell      = _ENV.shell

if multishell then
  multishell.setTitle(multishell.getCurrent(), 'Milo')
end

local config = {
  monitor = 'type/monitor',
  remoteDefaults = { },
}
Config.load('milo', config)

local modem = Peripheral.get('wired_modem')
if not modem or not modem.getNameLocal then
  error('Wired modem is not connected')
end

local function loadResources()
  local resources = Util.readTable(Milo.RESOURCE_FILE) or { }
  for k,v in pairs(resources) do
    Util.merge(v, itemDB:splitKey(k))
  end

  return resources
end

local context = {
  config = config,
  resources = loadResources(),
  userRecipes = Util.readTable(Milo.RECIPES_FILE) or { },
  learnTypes = { },
  machineTypes = { },
  localName = modem.getNameLocal(),
  tasks = { },
  craftingQueue = { },
}

_G._p = context--debug

local function initStorage(detachedDevice)
  debug('Initializing storage')
  local storage = { }
  local storageOffline

  -- check to see if any of the storage chests are disconnected
  for k,v in pairs(config.remoteDefaults) do
    if v.mtype == 'storage' then
      if not device[v.name] or v.name == detachedDevice then
        storageOffline = true
      else
        storage[k] = v
      end
    end
  end
debug(storage)

  if storageOffline then
    Milo:pauseCrafting()
    debug('Crafting paused')
    Milo:showError('A storage chest has gone offline, ctrl-l to continue')

-- todo: just can't resume crafting - need to use offline flag instead
-- in the case where crafting was paused already when storage went offline
-- ie. in crafting process
  elseif Milo:isCraftingPaused() then
    debug('resuming')
    Milo:resumeCrafting()
  end
--TODO: cannot do this, must be able to add and mark inactive
-- due to activity table
-- add an networkAdapter:scan()
  context.inventoryAdapter = NetworkAdapter({ remoteDefaults = storage })

  if not context.inventoryAdapter then
    error('Invalid inventory configuration')
  end
end

Event.on({ 'device_attach' }, function(_, dev)
  --debug('attach: ' .. dev)
  if config.remoteDefaults[dev] and
    config.remoteDefaults[dev].mtype == 'storage' then
    initStorage()
  end
end)

Event.on({ 'device_detach' }, function(_, dev)
  --debug('detach: ' .. dev)
  if config.remoteDefaults[dev] and
     config.remoteDefaults[dev].mtype == 'storage' then
    initStorage(dev)
  end
end)

initStorage()
Milo:init(context)

local function loadDirectory(dir)
  for _, file in pairs(fs.list(dir)) do
    local s, m = Util.run(_ENV, fs.combine(dir, file))
    if not s and m then
      error(m or 'Unknown error')
    end
  end
end

local programDir = fs.getDir(shell.getRunningProgram())
loadDirectory(fs.combine(programDir, 'core'))
loadDirectory(fs.combine(programDir, 'plugins'))

table.sort(context.tasks, function(a, b)
  return a.priority < b.priority
end)

debug('Tasks\n-----')
for _, task in ipairs(context.tasks) do
  debug('%d: %s', task.priority, task.name)
end

Milo:clearGrid()

local page = UI:getPage('listing')
UI:setPage(page)
page:setFocus(page.statusBar.filter) -- todo: move this line into listing code

Event.onInterval(500, function()
  if not Milo:isCraftingPaused() then
    Milo:resetCraftingStatus()
    context.inventoryAdapter:refresh()

    for _, task in ipairs(context.tasks) do
      local s, m = pcall(function() task:cycle(context) end)
      if not s and m then
        Util.print(task)
        error(m)
      end
    end
  end
end)

UI:pullEvents()
