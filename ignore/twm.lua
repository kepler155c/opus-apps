local Terminal = require('opus.terminal')
local trace    = require('opus.trace')
local Util     = require('opus.util')

local colors     = _G.colors
local os         = _G.os
local peripheral = _G.peripheral
local printError = _G.printError
local shell      = _ENV.shell
local term       = _G.term
local window     = _G.window

local function syntax()
	printError('Syntax:')
	error('mwm [--config=filename] [monitor]')
end

local args        = Util.parse(...)
local UID         = 0
local multishell  = { }
local processes   = { }
local parentTerm  = term.current()
local sessionFile = args.config or 'usr/config/mwm'
local monName     = args[1]
local running
local parentMon

local defaultEnv = Util.shallowCopy(_ENV)
defaultEnv.multishell = multishell

if monName == 'terminal' then
	parentMon = term.current()
elseif monName then
	parentMon = peripheral.wrap(monName) or syntax()
else
	parentMon = peripheral.find('monitor') or syntax()
end

if parentMon.setTextScale then
	parentMon.setTextScale(.5)
end

local monDim, termDim = { }, { }
monDim.width, monDim.height = parentMon.getSize()
termDim.width, termDim.height = parentTerm.getSize()

-- even though the monitor window is set to visible
-- the canvas is not (possibly change default in terminal.lua)

-- canvas is not visible so that redraws
-- are done once in the event loop
local monitor = Terminal.window(parentMon, 1, 1, monDim.width, monDim.height, true)
monitor.setBackgroundColor(colors.gray)
monitor.clear()

local function nextUID()
	UID = UID + 1
	return UID
end

local function xprun(env, path, ...)
	setmetatable(env, { __index = _G })
	local fn, m = loadfile(path, env)
	if fn then
		return trace(fn, ...)
	end
	return fn, m
end

local function write(win, x, y, text)
	win.setCursorPos(x, y)
	win.write(text)
end

local function redraw()
	--monitor.clear()
	monitor.canvas:dirty()
	--monitor.setBackgroundColor(colors.gray)
	monitor.canvas:clear(colors.gray)
	for k, process in ipairs(processes) do
		process.container.canvas:dirty()
		process:focus(k == #processes)
	end
end

local function getProcessAt(x, y)
	for k = #processes, 1, -1 do
		local process = processes[k]
		if x >= process.x and
			 y >= process.y and
			 x <= process.x + process.width - 1 and
			 y <= process.y + process.height - 1 then
			return k, process
		end
	end
end

--[[ A runnable process ]]--
local Process = { }

function Process:new(args)
	args.env = args.env or Util.shallowCopy(defaultEnv)
	args.width = args.width or math.floor(termDim.width * .75)
	args.height = args.height or math.floor(termDim.height * .75)

	-- TODO: randomize start position
	local self = setmetatable({
		uid    = nextUID(),
		x      = args.x or 1,
		y      = args.y or 1,
		width  = args.width,
		height = args.height + 1,
		path   = args.path,
		args   = args.args  or { },
		title  = args.title or 'shell',
		isMoving   = false,
		isResizing = false,
	}, { __index = Process })

	self:adjustDimensions()
	if not args.x then
		self.x = math.random(1, monDim.width - self.width + 1)
		self.y = math.random(1, monDim.height - self.height + 1)
	end

	self.container = Terminal.window(monitor, self.x, self.y, self.width, self.height, true)
	self.window = window.create(self.container, 1, 2, args.width, args.height, true)
	self.terminal = self.window

	self.container.canvas.parent = monitor.canvas
	table.insert(monitor.canvas.layers, 1, self.container.canvas)
	self.container.canvas:setVisible(true)

	--self.container.getSize = self.window.getSize

	self.co = coroutine.create(function()
		local result, err

		if args.fn then
			result, err = Util.runFunction(args.env, args.fn, table.unpack(self.args))
		elseif args.path then
			result, err = xprun(args.env, args.path, table.unpack(self.args))
		end

		if not result and err and err ~= 'Terminated' then
			printError('\n' .. tostring(err))
			os.pullEventRaw('terminate')
		end
		multishell.removeProcess(self)
	end)

	self:focus(false)

	return self
end

function Process:focus(focused)
	if focused then
		self.container.setBackgroundColor(colors.yellow)
	else
		self.container.setBackgroundColor(colors.lightGray)
	end
	self.container.setTextColor(colors.black)
	write(self.container, 1, 1, string.rep(' ', self.width))
	write(self.container, 2, 1, self.title)
	write(self.container, self.width - 1, 1, '*')
	write(self.container, self.width - 3, 1, '\029')

	if focused then
		self.window.restoreCursor()
	end
end

function Process:drawSizers()
	self.container.setBackgroundColor(colors.black)
	self.container.setTextColor(colors.yellow)
	local str = string.format('%d x %d', self.width - 2, self.height - 3)
	write(self.container, (self.width - #str) / 2, 1, str)
end

function Process:adjustDimensions()
	self.width = math.min(self.width, monDim.width)
	self.height = math.min(self.height, monDim.height)

	self.x = math.max(1, self.x)
	self.y = math.max(1, self.y)
	self.x = math.min(self.x, monDim.width - self.width + 1)
	self.y = math.min(self.y, monDim.height - self.height + 1)
end

function Process:reposition()
	self:adjustDimensions()
	self.container.reposition(self.x, self.y, self.width, self.height)
	self.container.setBackgroundColor(colors.black)
	self.container.clear()
	self.window.reposition(1, 2, self.width, self.height - 1)
	if self.window ~= self.terminal then
		if self.terminal.reposition then -- ??
			self.terminal.reposition(1, 1, self.width, self.height - 1)
		end
	end
	redraw()
end

function Process:click(x, y, rx, ry)
	if y == 1 then -- title bar
		if x == self.width - 1 then
			self:resume('terminate')
		elseif x == self.width - 3 then
			self.isResizing = { x = rx, y = ry, h = self.height, w = self.width }
		else
			self.isMoving = { x = rx, y = ry, ox = self.x, oy = self.y }
		end

	else
		if self.isMoving then
			self.isMoving = false
		end
		self:resume('mouse_click', 1, x, y - 1)
		self:resume('mouse_up',    1, x, y - 1)
	end
end

function Process:resize(x, y)
	self.height = y - self.isResizing.y + self.isResizing.h
	self.width  = x - self.isResizing.x + self.isResizing.w

	self:reposition()
	self:resume('term_resize')
	self:drawSizers()
	multishell.saveSession(sessionFile)
end

function Process:resume(event, ...)
	if coroutine.status(self.co) == 'dead' then
		return
	end

	if not self.filter or self.filter == event or event == "terminate" then
		--term.redirect(self.terminal)
		local previousTerm = term.redirect(self.terminal)

		local previous = running
		running = self -- stupid shell set title
		local ok, result = coroutine.resume(self.co, event, ...)
		running = previous

		self.terminal = term.current()
		term.redirect(previousTerm)

		if ok then
			self.filter = result
		else
			printError(result)
		end
		return ok, result
	end
end

--[[ Install a multishell manager for the monitor ]]--
function multishell.getFocus()
	return processes[#processes].uid
end

function multishell.setFocus(uid)
	local process = Util.find(processes, 'uid', uid)

	if process then
		local lastFocused = processes[#processes]
		if lastFocused ~= process then

			if lastFocused then
				lastFocused:focus(false)
			end

			Util.removeByValue(processes, process)
			table.insert(processes, process)

			process.container.canvas:raise()
			process:focus(true)
			process.container.canvas:dirty()
		end
		return true
	end
	return false
end

function multishell.getTitle(uid)
	local process = Util.find(processes, 'uid', uid)
	if process then
		return process.title
	end
end

function multishell.setTitle(uid, title)
	local process = Util.find(processes, 'uid', uid)
	if process then
		process.title = title or ''
		process:focus(process == processes[#processes])
	end
end

function multishell.getCurrent()
	if running then
		return running.uid
	end
end

function multishell.getCount()
	return #processes
end

function multishell.getTabs()
	return processes
end

function multishell.launch(env, file, ...)
	return multishell.openTab({
		path  = file,
		env   = env,
		title = 'shell',
		args  = { ... },
	})
end

function multishell.openTab(tabInfo)
	local process = Process:new(tabInfo)

	table.insert(processes, 1, process)

	--local previousTerm = term.current()
	process:resume()
	--term.redirect(previousTerm)

	multishell.saveSession(sessionFile)

	return process.uid
end

function multishell.removeProcess(process)
	Util.removeByValue(processes, process)
	process.container.canvas:removeLayer()

	multishell.saveSession(sessionFile)
	redraw()
end

function multishell.saveSession(filename)
	local t = { }
	for _,process in ipairs(processes) do
		if process.path then
			table.insert(t, {
				x = process.x,
				y = process.y,
				width = process.width,
				height = process.height - 1,
				path = process.path,
				args = process.args,
			})
		end
	end
	Util.writeTable(filename, t)
end

function multishell.loadSession(filename)
	local config = Util.readTable(filename)
	if config then
		for k = #config, 1, -1 do
			multishell.openTab(config[k])
		end
	end
end

function multishell.stop()
	multishell._stop = true
end

function multishell.start()
	while not multishell._stop do

		local event = { os.pullEventRaw() }

		if event[1] == 'terminate' then
			local focused = processes[#processes]
			if focused then
				focused:resume('terminate')
				if #processes == 0 then
					break
				end
			end

		elseif event[1] == 'monitor_touch' or event[1] == 'mouse_click' then --or event[1] == 'mouse_up' then
			local x, y = event[3], event[4]

			local key, process = getProcessAt(x, y)
			if process then
				if key ~= #processes then
					multishell.setFocus(process.uid)
					multishell.saveSession(sessionFile)
				end
				process:click(x - process.x + 1, y - process.y + 1, x, y)
			end

		elseif event[1] == 'mouse_up' then
			local focused = processes[#processes]
			if focused and (focused.isResizing or focused.isMoving) then
				multishell.saveSession(sessionFile)
				if focused.isResizing then
					focused:focus(true)
				end
			end
			if focused then
				focused.isResizing = nil
				focused.isMoving = false
			end

		elseif event[1] == 'mouse_drag' then
			local focused = processes[#processes]
			if focused then
				if focused.isResizing then
					focused:resize(event[3], event[4])

				elseif focused.isMoving then
					focused.x = event[3] - focused.isMoving.x + focused.isMoving.ox
					focused.y = event[4] - focused.isMoving.y + focused.isMoving.oy
					focused:reposition()
				end
			end

		elseif event[1] == 'char' or
					 event[1] == 'key' or
					 event[1] == 'key_up' or
					 event[1] == 'paste' then

			local focused = processes[#processes]
			if focused then
				focused:resume(table.unpack(event))
			end

		else
			for _,process in pairs(Util.shallowCopy(processes)) do
				process:resume(table.unpack(event))
			end
		end

		monitor.canvas:render(parentMon)

		local focused = processes[#processes]
		if focused then
			focused.window.restoreCursor()
		end
	end
end

multishell.loadSession(sessionFile)

if #processes == 0 then
	multishell.openTab({
		path  = 'sys/apps/shell.lua',
		title = 'shell',
	})
end

processes[#processes]:focus(true)
multishell.start()

term.redirect(parentTerm)
parentTerm.clear()
parentTerm.setCursorPos(1, 1)
