_G.requireInjector(_ENV)

local device = _G.device
local kernel = _G.kernel
local os     = _G.os

local glasses = require('shatter')
glasses.name = 'glasses'
glasses.type = 'rayban'
glasses.size = 'face'
device.glasses = glasses

glasses.setTextScale(.5)
glasses.setSize(100, 40)

kernel.hook({ 'glasses_click', 'glasses_up', 'glasses_drag' }, function(event, eventData)
	local sx, sy = 6, 9
	local scale = glasses.getTextScale()
	local ox, oy = math.ceil(scale*sx), math.ceil(scale*sy)

	local lookup = {
		glasses_click = 'monitor_touch',
		glasses_up = 'monitor_up',
		glasses_drag = 'monitor_drag',
	}
	local x, y = math.floor(eventData[2]/ox) + 1, math.floor(eventData[3]/oy) + 1
	os.queueEvent(lookup[event], 'glasses', x, y)

	glasses.setCursorPos(x, y)
	glasses.write('X ' .. eventData[3])
end)
