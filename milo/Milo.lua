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
  activityMonitor = 'none',
  remoteDefaults = { },
}
Config.load('milo', config)

local modem = Peripheral.get('wired_modem')
if not modem or not modem.getNameLocal then
  error('Wired modem is not connected')
end

local introspectionModule = Peripheral.get('plethora:introspection') or
  error('Introspection module not found')

local context = {
  config = config,
  resources = Util.readTable(Milo.RESOURCE_FILE) or { },

  craftingQueue = { },

  learnTypes = { },
  tasks = { },
  queue = { },

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

Event.on('milo_cycle', function()
  if not context.turtleBusy then
    context.turtleBusy = true
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
    context.turtleBusy = false
    if not Util.empty(context.queue) then
      os.queueEvent('milo_queue')
    end
  end
end)

Event.on('milo_queue', function()
  if not context.turtleBusy then
    context.turtleBusy = true

    for _, key in pairs(Util.keys(context.queue)) do
      local entry = context.queue[key]
      entry.callback(entry.request)
      context.queue[key] = nil
    end

    context.turtleBusy = false
  end
end)

Event.onInterval(5, function()
  if not Milo:isCraftingPaused() and context.storage:isOnline() then
    os.queueEvent('milo_cycle')
  end
end)

os.queueEvent(
  context.storage:isOnline() and 'storage_online' or 'storage_offline',
  context.storage:isOnline())

UI:pullEvents()
