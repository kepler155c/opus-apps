local os = _G.os
local peripheral = _G.peripheral

local running, modemSide
local tasks = { }

local sides = { 'front', 'back', 'left', 'right', 'top', 'bottom' }
for _,v in pairs(sides) do
  if peripheral.getType(v) == 'modem' and not peripheral.call(v, 'isWireless') then
    modemSide = v
    break
  end
end

if not modemSide then
  error('Must be conncted to a wired modem')
end

print('Using modem at side: ' .. modemSide)
peripheral.call(modemSide, 'open', 42)

local function addTask(fn)
  local task
  task = {
    co = coroutine.create(fn)
  }
  table.insert(tasks, task)
  return task
end

local function run()
  if #tasks > 0 then
    local event = { }

    while true do
      for n = #tasks, 1, -1 do
        local task = tasks[n]
        if coroutine.status(task.co) == 'dead' then
          table.remove(tasks, n)
        elseif task.filter == nil or task.filter == event[1] or event[1] == "terminate" then
          local ok, param = coroutine.resume(task.co, table.unpack(event))
          if not ok then
            _G.printError(param)
          else
            task.filter = param
          end
          if coroutine.status(task.co) == 'dead' then
            table.remove(tasks, n)
          end
        end
      end
      if #tasks == 0 then
        break
      end
      event = { os.pullEventRaw() }
    end
  end
end

local function startProgram(program)
  print('Starting: ' .. program.name)

  local sandbox = { }
  for k,v in pairs(_ENV) do
    sandbox[k] = v
  end

  local env = setmetatable(sandbox, { __index = _G })
  local fn, m = load(program.data, program.name, nil, env)
  if fn then
    running = addTask(function()
      pcall(fn)
      print('Ended: ' .. program.name)
    end)
  else
    _G.printError(m)
  end
end

addTask(function()
  print('Waiting for program...')
  while true do
    local _, side, dport, dhost, msg = os.pullEvent('modem_message')
    if side == modemSide and dport == 42 and dhost == os.getComputerID() then
      if running and coroutine.status(running.co) ~= 'dead' then
        coroutine.resume(running.co, 'terminate')
      end
      if msg.type == 'start' then
        startProgram(msg)
      end
      os.queueEvent('dummy')
    end
  end
end)

run()
