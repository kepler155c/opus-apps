requireInjector = requireInjector or load(http.get('https://raw.githubusercontent.com/kepler155c/opus/master/sys/apis/injector.lua').readAll())()
requireInjector(getfenv(1))

local Util = require('util')

local function syntax()
  printError('Syntax:')
  print('mwm sessionName [monitor]')
  error()
end

local args       = { ... }
local UID        = 0
local processes  = { }
local parentTerm = term.current()
local configFile = args[1] or syntax()
local defaultEnv = Util.shallowCopy(getfenv(1))
local monitor
local exitSession

if args[2] then
  monitor = peripheral.wrap(args[2]) or syntax()
else
  monitor = peripheral.find('monitor') or syntax()
end

monitor.setTextScale(.5)
monitor.clear()

local monDim, termDim = { }, { }
monDim.width, monDim.height = monitor.getSize()
termDim.width, termDim.height = parentTerm.getSize()

local function nextUID()
  UID = UID + 1
  return UID
end

local function saveSession()
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
  Util.writeTable(configFile, t)
end

local function write(win, x, y, text)
  win.setCursorPos(x, y)
  win.write(text)
end

local function redraw()
  monitor.clear()
  for k,process in ipairs(processes) do
    process.container.redraw()
    process:focus(k == #processes)
  end
end

local function focusProcess(process)
  if #processes > 0 then
    local lastFocused = processes[#processes]
    lastFocused:focus(false)
  end

  Util.removeByValue(processes, process)
  table.insert(processes, process)
  process:focus(true)
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
    uid = nextUID(),
    x = args.x or 1,
    y = args.y or 1,
    width = args.width + 2,
    height = args.height + 3,
    path = args.path,
    args = args.args  or { },
    title = args.title or 'shell',
  }, { __index = Process })

  self:adjustDimensions()

  self.container = window.create(monitor, self.x, self.y, self.width, self.height, true)
  self.titleBar = window.create(self.container, 2, 2, self.width - 2, 1, true)
  self.window = window.create(self.container, 2, 3, args.width, args.height, true)

  self.terminal = self.window

  self.co = coroutine.create(function()

    local result, err

    if args.fn then
      result, err = Util.runFunction(args.env, args.fn, table.unpack(self.args))
    elseif args.path then
      result, err = os.run(args.env, args.path, table.unpack(self.args))
    end

    if not result and err ~= 'Terminated' then
      if err then
        printError(tostring(err))
        os.sleep(3)
      end
    end
    Util.removeByValue(processes, self)
    saveSession()
    redraw()
  end)

  if #processes > 0 then
    processes[#processes]:focus(false)
  end
  table.insert(processes, self)
  self:focus(true)

  local previousTerm = term.current()
  self:resume()
  term.redirect(previousTerm)

  return self
end

function Process:focus(focused)
  if focused then
    self.titleBar.setBackgroundColor(colors.yellow)
  else
    self.titleBar.setBackgroundColor(colors.gray)
  end
  self.titleBar.clear()
  self.titleBar.setTextColor(colors.black)
  write(self.titleBar, 2, 1, self.title)
  write(self.titleBar, self.width - 3, 1, '*')

  if focused then
    self.window.restoreCursor()
  elseif self.showSizers then
    self:drawSizers(false)
  end
end

function Process:drawSizers(showSizers)

  self.showSizers = showSizers

  self.container.setBackgroundColor(colors.black)
  self.container.setTextColor(colors.white)

  if self.showSizers then
    write(self.container, 1, 1, '\135')
    write(self.container, self.width, 1, '\139')
    write(self.container, 1, self.height, '\141')
    write(self.container, self.width, self.height, '\142')

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

  self.titleBar.reposition(2, 2, self.width - 2, 1)
  self.window.reposition(2, 3, self.width - 2, self.height - 3)

  redraw()
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
  saveSession()
end

function Process:resume(event, ...)
  if coroutine.status(self.co) == 'dead' then
    return
  end

  if not self.filter or self.filter == event or event == "terminate" then
    term.redirect(self.terminal)

    local ok, result = coroutine.resume(self.co, event, ...)
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
defaultEnv.multishell = { }

function defaultEnv.multishell.getFocus()
  return processes[#processes].uid
end

function defaultEnv.multishell.setFocus(uid)
  local process, key = Util.find(processes, 'uid', uid)

  if process then
    if processes[#processes] ~= process then
      focusProcess(process)
    end
    return true
  end
  return false
end

function defaultEnv.multishell.getTitle(uid)
  local process = Util.find(processes, 'uid', uid)
  if process then
    return process.title
  end
end

function defaultEnv.multishell.setTitle(uid, title)
  local process = Util.find(processes, 'uid', uid)
  if process then
    process.title = title or ''
    process:focus(process == processes[#processes])
  end
end

function defaultEnv.multishell.getCurrent()
  if #processes > 0 then
    return processes[#processes].uid
  end
end

function defaultEnv.multishell.getCount()
  return #processes
end

function defaultEnv.multishell.launch(env, file, ...)
  return defaultEnv.multishell.openTab({
    path  = file,
    env   = env,
    title = 'shell',
    args  = { ... },
  })
end

function defaultEnv.multishell.openTab(tabInfo)
  local process = Process:new(tabInfo)
  saveSession()
  return process.uid
end

--[[ Special shell process for launching programs ]]--
local function addShell()

  local process = setmetatable({
    x       = monDim.width - 8,
    y       = monDim.height,
    width   = 9,
    height  = 1,
    isShell = true,
    uid     = nextUID(),
  }, { __index = Process })

  function process:focus(focused)
    self.window.setVisible(focused)
    if focused then
      self.window.restoreCursor()
      self.container.setTextColor(colors.yellow)
      self.container.setBackgroundColor(colors.black)
    else
      parentTerm.clear()
      parentTerm.setCursorBlink(false)
      self.container.setTextColor(colors.lightGray)
      self.container.setBackgroundColor(colors.black)
    end
    write(self.container, 1, 1, '[ shell ]')
  end

  function process:resizeClick()
  end

  function process:drawSizers()
  end

  process.container = window.create(monitor, process.x, process.y, process.width, process.height, true)
  process.window    = window.create(parentTerm, 1, 1, termDim.width, termDim.height, true)
  process.terminal  = process.window

  process.co = coroutine.create(function()
    print('To run a program on the monitor, type "fg <program>"')
    print('To quit, type "exit"')
    print('Press the [ shell ] button on the monitor to return to this shell')
    os.run(Util.shallowCopy(defaultEnv), shell.resolveProgram('shell'))
    exitSession = true
  end)

  table.insert(processes, process)

  process:focus(true)
  local previousTerm = term.current()
  process:resume()
  term.redirect(previousTerm)
end

local function loadSession()
  if fs.exists(configFile) then
    local config = Util.readTable(configFile)
    if config then
      for _,v in pairs(config) do
        Process:new(v)
      end
    end
  end
end

addShell()
loadSession()

while not exitSession do

  local event = { os.pullEventRaw() }

  if event[1] == 'terminate' then
    break

  elseif event[1] == "monitor_touch" then
    local x, y = event[3], event[4]

    local key, process = getProcessAt(x, y)
    if process then
      if key ~= #processes then
        focusProcess(process)
      end

      x = x - process.x + 1
      y = y - process.y + 1

      if y == 2 then -- title bar
        if x == process.width - 2 then
          process:resume('terminate')
        else
          process:drawSizers(not process.showSizers)
        end

      elseif x == 1 or y == 1 then -- sizers
        process:resizeClick(x, y)

      elseif x > 1 and x < process.width then
        if process.showSizers then
          process:drawSizers(false)
        end
        process:resume('mouse_click', 1, x - 1, y - 2)
        process:resume('mouse_up',    1, x - 1, y - 2)
      end
    else
      process = processes[#processes]
      if process and process.showSizers then
        process.x = math.floor(x - (process.width) / 2)
        process.y = y
        process:reposition()
        process:drawSizers(true)
        saveSession()
      end
    end

  elseif event[1] == "char" or
         event[1] == "key" or
         event[1] == "key_up" or
         event[1] == "paste" then

    local focused = processes[#processes]
    if focused then
      focused:resume(unpack(event))
    end

  else
    for _,process in pairs(Util.shallowCopy(processes)) do
      process:resume(unpack(event))
    end
    if processes[#processes] then
      processes[#processes].window.restoreCursor()
    end
  end
end

term.redirect(parentTerm)
parentTerm.clear()
parentTerm.setCursorPos(1, 1)
