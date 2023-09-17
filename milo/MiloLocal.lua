local Event      = require('opus.event')
local Milo       = require('milo')
local Sound      = require('opus.sound')
local Storage    = require('milo.storage')
local TurtleInv  = require('milo.turtleInv')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local colors     = _G.colors
local device     = _G.device
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell
local turtle     = _G.turtle

multishell.setTitle(multishell.getCurrent(), 'Milo')

local function Syntax(msg)
	print([[
Turtle must be provided with:
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

if not device.workbench then
	turtle.equip('right', 'minecraft:crafting_table:0')
	if not device.workbench then
		Syntax('Workbench missing')
	end
end

local localName = modem.getNameLocal()
TurtleInv.setLocalName(localName)

local context = {
	resources = Util.readTable(Milo.RESOURCE_FILE) or { },

	state = { },
	craftingQueue = { },
	tasks = { },
	queue = { },
	plugins = { },
	loggers = { },

	taskTimer = 0,
	taskCounter = 0,

	storage = Storage(),
	turtleInventory = {
		name = localName,
		mtype = 'hidden',
		adapter = TurtleInv,
	}
}

context.storage.nodes[localName] = context.turtleInventory
context.storage.nodes[localName].adapter.name = localName

Milo:init(context)
context.storage:initStorage()
context.storage.turtleInventory = context.turtleInventory

local function loadPlugin(file)
	local s, plugin = Util.run(_ENV, file, context)
	if not s and plugin then
		_G.printError('Error loading: ' .. file)
		error(plugin or 'Unknown error')
	end

	if plugin and type(plugin) == 'table' then
		Milo:registerPlugin(plugin)
	end
end

local function loadDirectory(dir)
	for _, file in pairs(fs.list(dir)) do
		if not fs.isDir(fs.combine(dir, file)) then
			loadPlugin(fs.combine(dir, file))
		end
	end
end

local programDir = fs.getDir(shell.getRunningProgram())
loadDirectory(fs.combine(programDir, 'core'))
loadDirectory(fs.combine(programDir, 'plugins'))
loadDirectory(fs.combine(programDir, 'plugins/item'))

for k in pairs(Milo:getState('plugins') or { }) do
	loadPlugin(k)
end

table.sort(context.tasks, function(a, b)
	return a.priority < b.priority
end)

_G._syslog('Tasks\n-----')
for _, task in ipairs(context.tasks) do
	task.execTime = 0
	_G._syslog('%d: %s', task.priority, task.name)
end

Milo:clearGrid()

UI:setPage(UI:getPage('listing'))
Sound.play('ui.toast.challenge_complete')

Event.on({ 'milo_cycle', 'milo_queue' }, function(e)
	if context.storage:isOnline() then
		if #context.queue > 0 then
			local queue = context.queue
			context.queue = { }
			for _, entry in pairs(queue) do
				local s, m = pcall(entry.callback, entry.request)
				if not s and m then
					_G._syslog('callback crashed')
					_G._syslog(m)
				end
			end
		end
	end

	if e == 'milo_cycle' and not Milo:isCraftingPaused() then
		local taskTimer = Util.timer()
		Milo:resetCraftingStatus()

		turtle.setStatus('Milo: tasks')

		for _, task in ipairs(context.tasks) do
			local timer = Util.timer()
			local s, m = pcall(function() task:cycle(context) end)
			if not s and m then
				_G._syslog(task.name .. ' crashed')
				_G._syslog(m)
			end
			task.execTime = task.execTime + timer()
		end
		turtle.setStatus('Milo: idle')

		context.taskTimer = context.taskTimer + taskTimer()
		context.taskCounter = context.taskCounter + 1
	end

	if context.storage:isOnline() and #context.queue > 0 then
		os.queueEvent('milo_cycle')
	end
end)

Event.on('turtle_inventory', function()
	Milo:queueRequest({ }, function()
		if not Milo:isCraftingPaused() then
			Milo:clearGrid()
		end
	end)
end)

Event.onInterval(5, function()
	Event.trigger('milo_cycle')
end)

Event.on({ 'storage_offline', 'storage_online' }, function()
	if context.storage:isOnline() then
		Milo:resumeCrafting({ key = 'storageOnline' })
		turtle.setStatus('Milo: online')
	else
		Milo:pauseCrafting({ key = 'storageOnline', msg = 'Storage offline' })
		turtle.setStatus('Milo: offline')
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

local oldDebug = _G._syslog
_G._syslog = function(...)
	for _,v in pairs(context.loggers) do
		v(...)
	end
	oldDebug(...)
end

local s, m = pcall(function()
	UI:start()
end)

if turtle.setStatus then
	turtle.setStatus('idle')
end

_G._syslog = oldDebug
if not s then error(m) end
