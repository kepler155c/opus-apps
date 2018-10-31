local Event  = require('event')
local Milo   = require('milo')

local device = _G.device

local RedstoneTask = {
	name = 'redstone',
	priority = 40,
}

function RedstoneTask:cycle(context)
	for v in context.storage:filterActive({ 'mtype', 'machine' }) do
		if v.redstone then
			local ri = device[v.redstone.integrator]
			if not ri or not v.adapter then
				_debug(v.redstone)
			else
				local function conditionsSatisfied()
					return not not next(v.adapter.list())
				end
				if conditionsSatisfied() then
					ri.setOutput(v.redstone.side, true)
					Event.onTimeout(.25, function()
						ri.setOutput(v.redstone.side, false)
					end)
				end
			end
		end
	end
end

Milo:registerTask(RedstoneTask)
