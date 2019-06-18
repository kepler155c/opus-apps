local class   = require('class')
local Event   = require('event')
local Map     = require('map')
local Proxy   = require('core.proxy')

local Swarm = class()
function Swarm:init(args)
	self.pool = { }
	Map.merge(self, args)
end

function Swarm:add(id, args)
	local member = Map.shallowCopy(args or { })
	member.id = id
	self.pool[id] = member
end

function Swarm:remove(id, s, m)
	local member = self.pool[id]
	if member then
		self.pool[id] = nil
		self:onRemove(member, s, m)
		if member.socket then
			member.socket:close()
			member.socket = nil
		end
		if member.handler then
			member.handler:terminate()
			member.handler = nil
		end
	end
end

function Swarm:run(fn)
	for id, member in pairs(self.pool) do
		if not member.socket then
			member.handler = Event.addRoutine(function()
				local s, m = pcall(function()
					member.turtle, member.socket = Proxy.create(id, 'turtle')

					fn(member)
				end)
				self:remove(id, s, m)
			end)
		end
	end
end

function Swarm:stop()
	for _, member in pairs(self.pool) do
		if member.socket then
			member.socket:close()
			member.socket = nil
		end
	end
end

-- Override
function Swarm:onRemove(member, success, msg)
	print('removed from pool: ' .. member.id)
	if not success then
		_G.printError(msg)
	end
end

return Swarm
