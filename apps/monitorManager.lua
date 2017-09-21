requireInjector(getfenv(1))

local Util = require('util')

local args = { ... }
local processes = { }
local parentTerm = term.current()

local function syntax()
  printError('Syntax:')
  printError('Start a new session')
  print('monitorManager start [configFile] [monitor]')
  print()
  printError('Run programs in session')
  print('monitorManager run [program] [arguments]')
  print()
  error()
end

local option = table.remove(args, 1)

if option == 'run' then
  local run = table.remove(args, 1)
  if not run then
    syntax()
  end
  os.queueEvent('monitor_client', { run = run, args = args })
  return
end

if option ~= 'start' then
  syntax()
end

local configFile = args[1] or syntax()
local monitor = peripheral.find(args[2] or 'monitor') or syntax()
monitor.setTextScale(.5)
monitor.clear()

local monDim = { }
monDim.width, monDim.height = monitor.getSize()

if fs.exists(configFile) then
  local config = Util.readTable(configFile)
  if config then
    for _,v in pairs(config) do
      os.queueEvent('monitor_client', v)
    end
  end
end

local function saveConfig()
  local t = { }
  for _,process in pairs(processes) do
    process.args.x = process.x
    process.args.y = process.y
    process.args.width = process.width - 2
    process.args.height = process.height - 3
    table.insert(t, process.args)
  end
  Util.writeTable(configFile, t)
end

local function write(win, x, y, text)
  win.setCursorPos(x, y)
  win.write(text)
end

local function redraw()
  monitor.clear()
  for k,process in pairs(processes) do
    process.container.redraw()
    process:focus(k == #processes)
  end
end

local Process = { }

function Process:focus(focused)
  if focused then
    self.titleBar.setBackgroundColor(colors.green)
  else
    self.titleBar.setBackgroundColor(colors.gray)
  end
  self.titleBar.clear()
  self.titleBar.setTextColor(colors.black)
  self.titleBar.setCursorPos(2, 1)
  self.titleBar.write(self.title or 'Terminal')

  self.titleBar.setCursorPos(self.width - 3, 1)
  self.titleBar.write('*')

  if focused then
    self.window.restoreCursor()
  end
end

function Process:drawSizers()
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

function Process:new(args)
  self.args = args

  args.width = args.width or 42
  args.height = args.height or 18

  self.x = args.x or 1
  self.y = args.y or 1
  self.width = args.width + 2
  self.height = args.height + 3

  self:adjustDimensions()

  self.container = window.create(monitor, self.x, self.y, self.width, self.height, true)
  self.titleBar = window.create(self.container, 2, 2, self.width - 2, 1, true)
  self.window = window.create(self.container, 2, 3, args.width, args.height, true)

  self.terminal = self.window

  self.co = coroutine.create(function()

    local result, err = shell.run('shell', args.run)

Util.print({ result, err })
    if not result and err ~= 'Terminated' then
      if err then
Util.print(tostring(err))
        printError(tostring(err))
        os.sleep(3)
      end
    end
    for k,v in pairs(processes) do
      if v == self then
        table.remove(processes, k)
        break
      end
    end
Util.print('dead')
      read()
    --saveConfig()
    redraw()
  end)

  self:focus(true)
  self:resume()
  self.title = multishell.getTab(multishell.getCurrent()).title

  return tab
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
  self:drawSizers()
  saveConfig()
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

function getProcessAt(x, y)
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

while true do

  local event = { os.pullEventRaw() }

  if event[1] == 'terminate' then
    term.redirect(parentTerm)
    break

  elseif event[1] == 'monitor_client' then
    local process = { }
    setmetatable(process, { __index = Process })

    local focused = processes[#processes]
    if focused then
      focused:focus(false)
    end

    table.insert(processes, process)
    process:new(event[2])
    saveConfig()

  elseif event[1] == "monitor_touch" then
    local x, y = event[3], event[4]

    local key, process = getProcessAt(x, y)
    if process then
      if key ~= #processes then
        local focused = processes[#processes]
        focused:focus(false)
        process:focus(true)
        table.remove(processes, key)
        table.insert(processes, process)
      end

      x = x - process.x + 1
      y = y - process.y + 1

      if y == 2 then -- title bar
        if x == process.width - 2 then
          process:resume('terminate')
        else
          process.showSizers = not process.showSizers
          process:drawSizers()
        end

      elseif x == 1 or y == 1 then -- sizers
        process:resizeClick(x, y)

      elseif x > 1 and x < process.width then
        if process.showSizers then
          process.showSizers = false
          process:drawSizers()
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
        process:drawSizers()
        saveConfig()
      end
    end

  elseif event == "char" or
         event == "key" or
         event == "key_up" or
         event == "paste" then

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
