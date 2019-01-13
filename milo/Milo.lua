local Event      = require('event')
local Milo       = require('milo')
local Sound      = require('sound')
local Storage    = require('storage')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors
local device     = _G.device
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell
local turtle     = _G.turtle

if multishell then
  multishell.setTitle(multishell.getCurrent(), 'Milo')
end

local function Syntax(msg)
  print([[
Turtle must be provided with:
  * Introspection module (never bound)
  * Workbench

Turtle must be connected to:
  * Wired modem (activated)
]])

  error(msg)
end

local modem
for _,v in pairs(device) do
  if v.type == 'wired_modem' then
    if modem then
      Syntax('Only 1 wired modem can be connected')
    end
    modem = v
  end
end

if not modem or not modem.getNameLocal then
  Syntax('Wired modem missing')
end

if not modem.getNameLocal() then
  Syntax('Wired modem is not active')
end

local introspection = device['plethora:introspection'] or
  turtle.equip('left', 'plethora:module:0') and device['plethora:introspection'] or
  Syntax('Introspection module missing')

if not device.workbench then
  turtle.equip('right', 'minecraft:crafting_table:0')
  if not device.workbench then
    Syntax('Workbench missing')
  end
end

local localName = modem.getNameLocal()

local context = {
  resources = Util.readTable(Milo.RESOURCE_FILE) or { },

  state = { },
  craftingQueue = { },
  tasks = { },
  queue = { },

  storage = Storage(),
  turtleInventory = {
    name = localName,
    mtype = 'hidden',
    adapter = introspection.getInventory(),
  }
}

context.storage.nodes[localName] = context.turtleInventory
context.storage.nodes[localName].adapter.name = localName

Milo:init(context)
context.storage:initStorage()
context.storage.turtleInventory = context.turtleInventory

local function loadDirectory(dir)
  for _, file in pairs(fs.list(dir)) do
    if not fs.isDir(fs.combine(dir, file)) then
      local s, m = Util.run(_ENV, fs.combine(dir, file), context)
      if not s and m then
        _G.printError('Error loading: ' .. file)
        error(m or 'Unknown error')
      end
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
Sound.play('ui.toast.challenge_complete')

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

Event.on('turtle_inventory', function()
  if not processing and not Milo:isCraftingPaused() then
    Milo:clearGrid()
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

Event.on('terminate', function()
  for _, node in pairs(context.storage.nodes) do
    if node.category == 'display' and node.adapter and node.adapter.clear then
      node.adapter.setBackgroundColor(colors.black)
      node.adapter.clear()
    end
  end
end)

os.queueEvent(
  context.storage:isOnline() and 'storage_online' or 'storage_offline',
  context.storage:isOnline())

UI:pullEvents()
