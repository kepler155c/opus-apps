--[[
  Provides: autocrafting, resource limits, on-demand crafting, storage stocker.

  Using a turtle allows for crafting of items eliminating the need for AE/RS
  molecular assemblers / crafters.

  Turtle crafting:
    1. The turtle must have a crafting table equipped.
    2. Equip the turtle with an introspection module.

  Configuration:
    Configuration file is usr/config/milo

    monitor   : valid options include:
                   type/monitor   - will use the first monitor found
                   side/north     - specify a direction (top/bottom/east/etc)
                   name/monitor_1 - specify the exact name of the peripheral
]]--

_G.requireInjector(_ENV)

local Config     = require('config')
local Event      = require('event')
local itemDB     = require('itemDB')
local Milo       = require('milo')
local Peripheral = require('peripheral')
local Storage    = require('storage')
local UI         = require('ui')
local Util       = require('util')

local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
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

local introspectionModule = Peripheral.get('plethora:introspection') or
  error('Introspection module not found')

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

  craftingQueue = { },

  learnTypes = { },
  tasks = { },

  localName = modem.getNameLocal(),
  storage = Storage(config),
  introspectionModule = introspectionModule,
}

_G._p = context --debug

Event.on('storage_offline', function()
  Milo:showError('A storage chest has gone offline, ctrl-l to continue')
end)

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

local page = UI:getPage('listing')
UI:setPage(page)

Event.onInterval(5, function()
  if not Milo:isCraftingPaused() and context.storage:isOnline() then
    Milo:resetCraftingStatus()
    --Milo:refreshItems()

    for _, task in ipairs(context.tasks) do
      local s, m = pcall(function() task:cycle(context) end)
      if not s and m then
        _debug(task.name .. ' crashed')
        Util.print(task.name .. ' crashed')
        error(m)
      end
    end
  end
end)

os.queueEvent(
  context.storage:isOnline() and 'storage_online' or 'storage_offline',
  context.storage:isOnline())

UI:pullEvents()
