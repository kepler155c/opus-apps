--[[
  Provides: autocrafting, resource limits, on-demand crafting, storage stocker.

  Using a turtle allows for crafting of items eliminating the need for AE/RS
  molecular assemblers / crafters.

  Turtle crafting:
    1. The turtle must have a crafting table equipped.
    2. Equip the turtle with an introspection module.
]]--

_G.requireInjector(_ENV)

local Config     = require('config')
local Event      = require('event')
local Milo       = require('milo')
local Peripheral = require('peripheral')
local Storage    = require('storage')
local UI         = require('ui')
local Util       = require('util')

local device     = _G.device
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell

if multishell then
  multishell.setTitle(multishell.getCurrent(), 'Milo')
end

local config = {
  nodes = { },
}
Config.load('milo', config)

-- TODO: remove - temporary
if config.remoteDefaults then
  config.nodes = config.remoteDefaults
  config.remoteDefaults = nil
end

-- TODO: remove - temporary
for _, node in pairs(config.nodes) do
  if node.lock and type(node.lock) == 'string' then
    node.lock = {
      [ node.lock ] = true,
    }
  end
end

local function Syntax(msg)
  print([[
Turtle must be equipped with:
  * Introspection module
  * Workbench

Turtle must be connected to:
  * Wired modem
]])

  error(msg)
end

local modem = Peripheral.get('wired_modem')
if not modem or not modem.getNameLocal then
  Syntax('Wired modem missing')
end

if not modem.getNameLocal() then
  Syntax('Wired modem is not active')
end

local introspection = Peripheral.get('plethora:introspection') or
  Syntax('Introspection module missing')

if not device.workbench then
  Syntax('Workbench missing')
end

local context = {
  config = config,
  resources = Util.readTable(Milo.RESOURCE_FILE) or { },

  state = { },
  craftingQueue = { },
  learnTypes = { },
  tasks = { },
  queue = { },

  localName = modem.getNameLocal(),
  storage = Storage(config),
  turtleInventory = introspection.getInventory(),
}

device[context.localName] = introspection.getInventory()

_G._p = context --debug

Milo:init(context)
context.storage:initStorage()

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

_debug('Tasks\n-----')
for _, task in ipairs(context.tasks) do
  _debug('%d: %s', task.priority, task.name)
end

Milo:clearGrid()

UI:setPage(UI:getPage('listing'))

local processing

Event.on('milo_cycle', function()
  if not processing and not Milo:isCraftingPaused() then
    processing = true
    Milo:resetCraftingStatus()

    for _, task in ipairs(context.tasks) do
      local s, m = pcall(function() task:cycle(context) end)
      if not s and m then
        _G._debug(task.name .. ' crashed')
        _G._debug(m)
        -- _G.printError(task.name .. ' crashed')
        -- _G.printError(m)
      end
    end
    processing = false
    if not Util.empty(context.queue) then
      os.queueEvent('milo_queue')
    end
  end
end)

Event.on('milo_queue', function()
  if not processing and context.storage:isOnline() then
    processing = true

    for _, key in pairs(Util.keys(context.queue)) do
      local entry = context.queue[key]
      entry.callback(entry.request)
      context.queue[key] = nil
    end

    processing = false
  end
end)

Event.onInterval(5, function()
  if not Milo:isCraftingPaused() then
    os.queueEvent('milo_cycle')
  end
end)

Event.on({ 'storage_offline', 'storage_online' }, function()
  if context.storage:isOnline() then
    Milo:resumeCrafting({ key = 'storageOnline' })
  else
    Milo:pauseCrafting({ key = 'storageOnline', msg = 'Storage offline' })
  end
end)

os.queueEvent(
  context.storage:isOnline() and 'storage_online' or 'storage_offline',
  context.storage:isOnline())

UI:pullEvents()
