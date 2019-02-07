if not _G.requireInjector then
  _ENV.LUA_PATH='https://raw.githubusercontent.com/kepler155c/opus/develop-1.8/sys/apis'
  load(_G.http.get(_ENV.LUA_PATH .. '/injector.lua').readAll())()(_ENV)
end

local Terminal = require('terminal')
local trace    = require('trace')
local Util     = require('util')

local colors     = _G.colors
local os         = _G.os
local peripheral = _G.peripheral
local printError = _G.printError
local shell      = _ENV.shell
local term       = _G.term
local window     = _G.window

local function syntax()
  printError('Syntax:')
  error('mwm sessionName [monitor]')
end

local args        = { ... }
local UID         = 0
local multishell  = { }
local processes   = { }
local parentTerm  = term.current()
local sessionFile = args[1] or 'usr/config/mwm'
local running
local parentMon

local defaultEnv = Util.shallowCopy(_ENV)
defaultEnv.multishell = multishell
if args[3] then
  parentMon = _G.device[args[3]]
elseif args[2] then
  parentMon = peripheral.wrap(args[2]) or syntax()
else
  parentMon = peripheral.find('monitor') or syntax()
end

parentMon.setTextScale(.5)

local monDim, termDim = { }, { }
monDim.width, monDim.height = parentMon.getSize()
termDim.width, termDim.height = parentTerm.getSize()

local monitor = Terminal.window(parentMon, 1, 1, monDim.width, monDim.height, false)
monitor.setBackgroundColor(colors.gray)
monitor.clear()

monitor.canvas:setVisible(true)

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
  for k,process in ipairs(processes) do
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
  args.width = args.width or termDim.width
  args.height = args.height or termDim.height

  local self = setmetatable({
    uid    = nextUID(),
    x      = args.x or 1,
    y      = args.y or 1,
    width  = args.width + 2,
    height = args.height + 3,
    path   = args.path,
    args   = args.args  or { },
    title  = args.title or 'shell',
  }, { __index = Process })

  self:adjustDimensions()

  self.container = Terminal.window(monitor, self.x, self.y, self.width, self.height, false)
  self.window = window.create(self.container, 2, 3, args.width, args.height, true)

  self.terminal = self.window

  self.container.canvas.parent = monitor.canvas
  table.insert(monitor.canvas.layers, self.container.canvas)
  self.container.canvas:setVisible(true)

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
    self.container.setBackgroundColor(colors.gray)
  end
  self.container.setTextColor(colors.black)
  write(self.container, 2, 2, string.rep(' ', self.width - 2))
  write(self.container, 3, 2, self.title)
  write(self.container, self.width - 2, 2, '*')

  if focused then
    self.window.restoreCursor()
  elseif self.showSizers then
    self:drawSizers(false)
  end
end

function Process:drawSizers(showSizers)
  local sizeChars = {
    '\135', '\139', '\141', '\142'
  }

  if Util.getVersion() < 1.8 then
    sizeChars = {
      '#', '#', '#', '#'
    }
  end

  self.showSizers = showSizers

  self.container.setBackgroundColor(colors.black)
  self.container.setTextColor(colors.white)

  if self.showSizers then
    write(self.container, 1, 1, sizeChars[1])
    write(self.container, self.width, 1, sizeChars[2])
    write(self.container, 1, self.height, sizeChars[3])
    write(self.container, self.width, self.height, sizeChars[4])

    self.container.setTextColor(colors.yellow)
    write(self.container, 1, 3, '+')
    write(self.container, 1, 5, '-')
    write(self.container, 3, 1, '+')
    write(self.container, 5, 1, '-')

    local str = string.format('%d x %d', self.width - 2, self.height - 3)
    write(self.container, (self.width - #str) / 2, 1, str)

  else
    write(self.container, 1, 1, string.rep(' ', self.width))
    write(self.container, self.width, 1, ' ')
    write(self.container, 1, self.height, ' ')
    write(self.container, self.width, self.height, ' ')
    write(self.container, 1, 3, ' ')
    write(self.container, 1, 5, ' ')
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

  self.window.reposition(2, 3, self.width - 2, self.height - 3)

  redraw()
end

function Process:click(x, y)
  if y == 2 then -- title bar
    if x == self.width - 2 then
      self:resume('terminate')
    else
      self:drawSizers(not self.showSizers)
    end

  elseif x == 1 or y == 1 then -- sizers
    self:resizeClick(x, y)

  elseif x > 1 and x < self.width then
    if self.showSizers then
      self:drawSizers(false)
    end
    self:resume('mouse_click', 1, x - 1, y - 2)
    self:resume('mouse_up',    1, x - 1, y - 2)
  end
end

function Process:resizeClick(x, y)
  if x == 1 and y == 3 then
    self.height = self.height + 1
  elseif x == 1 and y == 5 then
    self.height = self.height - 1
  elseif x == 3 and y == 1 then
    self.width = self.width + 1
  elseif x == 5 and y == 1 then
    self.width = self.width - 1
  else
    return
  end
  self:reposition()
  self:resume('term_resize')
  self:drawSizers(true)
  multishell.saveSession(sessionFile)
end

function Process:resume(event, ...)
  if coroutine.status(self.co) == 'dead' then
    return
  end

  if not self.filter or self.filter == event or event == "terminate" then
    term.redirect(self.terminal)

    local previous = running
    running = self -- stupid shell set title
    local ok, result = coroutine.resume(self.co, event, ...)
    running = previous

    self.terminal = term.current()
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

  --process.container.canvas:setVisible(true)

  local previousTerm = term.current()
  process:resume()
  term.redirect(previousTerm)

  multishell.saveSession(sessionFile)
  return process.uid
end

function multishell.restack()       -- reset the stacking order
  for k,v in ipairs(processes) do
    v.container.canvas.layers = { }
    for l = k + 1, #processes do
      table.insert(v.container.canvas.layers, processes[l].container.canvas)
    end
  end
end

function multishell.removeProcess(process)
  Util.removeByValue(processes, process)
  process.container.canvas:removeLayer()

  multishell.saveSession(sessionFile)
  --redraw()
end

function multishell.saveSession(filename)
  local t = { }
  for _,process in pairs(processes) do
    if process.path and not process.isShell then
      table.insert(t, {
        x = process.x,
        y = process.y,
        width = process.width - 2,
        height = process.height - 3,
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
    for _,v in pairs(config) do
      multishell.openTab(v)
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
        end
        process:click(x - process.x + 1, y - process.y + 1)

      else
        process = processes[#processes]
        if process and process.showSizers then
          process.x = math.floor(x - (process.width) / 2)
          process.y = y
          process:reposition()
          process:drawSizers(true)
          multishell.saveSession(sessionFile)
        end
      end

    elseif event[1] == 'mouse_click' or
           event[1] == 'mouse_up' then

      local focused = processes[#processes]
      if not focused.isShell then
        multishell.setFocus(1) -- shell is always 1
      else
        focused:resume(unpack(event))
      end

    elseif event[1] == 'char' or
           event[1] == 'key' or
           event[1] == 'key_up' or
           event[1] == 'paste' then

      local focused = processes[#processes]
      if focused then
        focused:resume(unpack(event))
      end

    else
      for _,process in pairs(Util.shallowCopy(processes)) do
        process:resume(unpack(event))
      end
    end

    monitor.canvas:render(parentMon)
    local didRedraw = true

    local focused = processes[#processes]
    if didRedraw and focused then
      --focused.container.canvas:dirty()
      --focused.container.canvas:redraw(parentTerm)
      focused.window.restoreCursor()
      local cx, cy = focused.container.getCursorPos()
      monitor.setCursorPos(
        focused.container.canvas.x + cx - 1,
        focused.container.canvas.y + cy - 1)
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
    --self.window.setVisible(focused)
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
    os.run(Util.shallowCopy(defaultEnv), shell.resolveProgram('shell'))
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
