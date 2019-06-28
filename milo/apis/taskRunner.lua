local class = require('opus.class')

local os = _G.os

local TaskRunner = class()
local free = { }

local function createTask(fn)
	local task = table.remove(free)
	if not task then
		task = {
			fn = fn,
			co = coroutine.create(function()
				local args = { }
				while true do
					pcall(task.fn, table.unpack(args))
					task.dead = true
					table.insert(free, task)
					args = { coroutine.yield() }
				end
			end)
		}
	else
		task.dead = nil
		task.fn = fn
	end
	return task
end

function TaskRunner:init(args)
	self.tasks = { }
	self.errorMsg = 'Task failed: '

	for k,v in pairs(args or { }) do
		self[k] = v
	end
end

function TaskRunner:add(fn)
	table.insert(self.tasks, createTask(fn))
end

function TaskRunner:run()
	if #self.tasks > 0 then
		local event = { }

		while true do
			for n = #self.tasks, 1, -1 do
				local task = self.tasks[n]
				if task.filter == nil or task.filter == event[1] or event[1] == "terminate" then
					local ok, param = coroutine.resume(task.co, table.unpack(event))
					if not ok then
						self:onError(param)
					else
						task.filter = param
					end
					if task.dead then
						table.remove(self.tasks, n)
					end
				end
			end
			if #self.tasks == 0 then
				break
			end
			event = { os.pullEventRaw() }
		end
	end
end

function TaskRunner:onError(msg)
	_G._syslog(msg.errorMsg .. msg)
end

return TaskRunner
