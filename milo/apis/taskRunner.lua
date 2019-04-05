local class = require('class')

local parallel = _G.parallel

local TaskRunner = class()

function TaskRunner:init(args)
  self.tasks = { }
  self.errorMsg = 'Task failed: '

  for k,v in pairs(args or { }) do
    self[k] = v
  end
end

function TaskRunner:add(fn)
  table.insert(self.tasks, function()
    local s, m = pcall(fn)
    if not s and m then
      self:onError(m)
    end
  end)
end

function TaskRunner:run()
  if #self.tasks > 0 then
    parallel.waitForAll(table.unpack(self.tasks))
  end
end

function TaskRunner:onError(msg)
  _G._debug(msg.errorMsg .. msg)
end

return TaskRunner
