local Event  = require('event')
local Milo   = require('milo')

local device = _G.device

local RedstoneTask = {
	name = 'redstone',
	priority = 40,
}

function RedstoneTask:cycle(context)
	for _,v in pairs(context.config.remoteDefaults) do
		if v.redstone then
			local ri = device[v.redstone.integrator]
			local function conditionsSatisfied()
				return not not next(ri.list())
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

Milo:registerTask(RedstoneTask)
