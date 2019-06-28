local Point  = require('opus.point')
local Util   = require('opus.util')

local device = _G.device
local os     = _G.os
local turtle = _G.turtle

local function convert(blocks, reference)
	if not reference then
		return blocks
	end

	local rotated = {
		[0] = 0,
		[1] = 3,
		[2] = 2,
		[3] = 1,
	}
	return Util.reduce(blocks, function(acc, b)
		local c = Util.shallowCopy(b)
		Point.rotate(c, rotated[reference.heading])
		c.x = c.x + reference.x
		c.y = c.y + reference.y
		c.z = c.z + reference.z
		table.insert(acc, c)
		return acc
	end, { })
end

local function broadcast(blocks, displayType, source)
	if device.wireless_modem then
		device.wireless_modem.transmit(3773, os.getComputerID(), {
			type = displayType,
			data = convert(blocks, source),
		})
	end
end

while true do
	local _, msg = os.pullEvent('canvas')

	local reference = turtle and turtle.getState().reference

	broadcast(msg.data, msg.type, reference)
end
