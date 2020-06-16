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
	error('Syntax:\nmwm [--config=filename] [monitor]')
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

_ENV.multishell = multishell
if monName then
	parentMon = peripheral.wrap(monName) or syntax()
else
	parentMon = peripheral.find('monitor') or syntax()
end

parentMon.setTextScale(.5)

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

function Process:new(env, args)
	args.env = shell.makeEnv(env)
	args.width = args.width or termDim.width
	args.height = args.height or termDim.height

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
	}, { __index = Process })

	self:adjustDimensions()
	if not args.x then
		self.x = math.random(1, monDim.width - self.width + 1)
		self.y = math.random(1, monDim.height - self.height + 1)
	end

	self.container = Terminal.window(monitor, self.x, self.y, self.width, self.height, true)
	self.window = window.create(self.container, 1, 2, args.width, args.height, true)
	self.terminal = self.window

	self.container.setBackgroundColor(colors.black)
	self.container.clear()

	self.container.canvas.parent = monitor.canvas
	if not monitor.canvas.children then
		monitor.canvas.children = { }
	end
	table.insert(monitor.canvas.children, 1, self.container.canvas)
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

function Process:drawTitle(focused)
	if self.showSizers and focused then
		local sizers = '\25 \26 \24 \27'

		self.container.setBackgroundColor(colors.yellow)
		self.container.setTextColor(colors.black)

		write(self.container, 1, 1, string.rep(' ', self.width))
		write(self.container, 2, 1, sizers)

		local str = string.format('%d x %d', self.width, self.height - 1)
		write(self.container, 10, 1, str)
	else
		if focused then
			self.container.setBackgroundColor(colors.yellow)
		else
			self.container.setBackgroundColor(colors.lightGray)
		end
		self.container.setTextColor(colors.black)
		write(self.container, 1, 1, string.rep(' ', self.width))
		write(self.container, 2, 1, self.title)
	end
	write(self.container, self.width - 1, 1, '*')
end

function Process:focus(focused)
	self:drawTitle(focused)
	if focused then
		self.window.restoreCursor()
	end
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
		self.terminal.reposition(1, 1, self.width, self.height - 1)
	end
	redraw()
end

function Process:click(x, y)
	if y == 1 then -- title bar
		if x == self.width - 1 then
			self:resume('terminate')
		elseif not self.showSizers then
			self.showSizers = not self.showSizers
			self:drawTitle(true)
		else
			self:resizeClick(x, y)
		end
	elseif x > 1 and x < self.width then
		if self.showSizers then
			self.showSizers = false
			self:drawTitle(true)
		end
		self:resume('mouse_click', 1, x, y - 1)
		self:resume('mouse_up',    1, x, y - 1)
	end
end

function Process:resizeClick(x)
	if x == 2 then
		self.height = self.height + 1
	elseif x == 6 then
		self.height = self.height - 1
	elseif x == 4 then
		self.width = self.width + 1
	elseif x == 8 then
		self.width = self.width - 1
	else
		return
	end
	self:reposition()
	self:resume('term_resize')
	self:drawTitle(true)
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
	return multishell.openTab(env, {
		path  = file,
		env   = env,
		title = 'shell',
		args  = { ... },
	})
end

function multishell.openTab(env, tabInfo)
	local process = Process:new(env, tabInfo)

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
		if process.path and not process.isShell then
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
			multishell.openTab(_ENV, config[k])
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
			if focused.isShell then
				focused:resume('terminate')
			else
				break
			end

		elseif event[1] == 'monitor_touch' then
			local x, y = event[3], event[4]

			local key, process = getProcessAt(x, y)
			if process then
				if key ~= #processes then
					multishell.setFocus(process.uid)
					multishell.saveSession(sessionFile)
				end
				process:click(x - process.x + 1, y - process.y + 1)

			else
				process = processes[#processes]
				if process and process.showSizers then
					process.x = math.floor(x - (process.width) / 2)
					process.y = y
					process:reposition()
					process:drawTitle(true)
					multishell.saveSession(sessionFile)
				end
			end

		elseif event[1] == 'mouse_click' or
					 event[1] == 'mouse_up' then

			local focused = processes[#processes]
			if not focused.isShell then
				multishell.setFocus(1) -- shell is always 1
			else
				focused:resume(table.unpack(event))
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

--[[ Special shell process for launching programs ]]--
local function addShell()

	local process = setmetatable({
		x       = monDim.width,
		y       = monDim.height,
		width   = 1,
		height  = 1,
		isShell = true,
		uid     = nextUID(),
		title   = 'Terminal',
	}, { __index = Process })

	function process:focus(focused)
		self.window.setVisible(focused)
		if focused then
			self.window.restoreCursor()
		else
			parentTerm.clear()
			parentTerm.setCursorBlink(false)
			local str = 'Click screen for shell'
			write(parentTerm,
				math.floor((termDim.width - #str) / 2),
				math.floor(termDim.height / 2),
				str)
		end
	end

	function process:click()
	end

	process.container = Terminal.window(monitor, process.x, process.y+1, process.width, process.height, true)
	process.window    = window.create(parentTerm, 1, 1, termDim.width, termDim.height, true)
	process.terminal  = process.window

	process.co = coroutine.create(function()
		print('To run a program on the monitor, type "fg <program>"')
		print('To quit, type "exit"')
		os.run(shell.makeEnv(_ENV), shell.resolveProgram('shell'))
		multishell.stop()
	end)

	table.insert(processes, process)
	process:focus(true)

	local previousTerm = term.current()
	process:resume()
	term.redirect(previousTerm)
end

addShell()

multishell.loadSession(sessionFile)
multishell.start()

term.redirect(parentTerm)
parentTerm.clear()
parentTerm.setCursorPos(1, 1)
