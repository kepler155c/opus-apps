local GPS  = require('gps')
local Util = require('util')

local os         = _G.os
local peripheral = _G.peripheral
local shell      = _ENV.shell

local args = { ... }
local fileName = args[1] or 'neural.tbl'

local t = Util.readTable(shell.resolve(fileName)) or error('Unable to read ' .. fileName)
local ni = peripheral.find('neuralInterface')

local function walkTo(x, y, z)
	local pt = GPS.locate(2)
	if pt then
		local s, m, m2 = pcall(function()
			local gpt = {
				x = x - pt.x,
				y = math.floor(y) - math.floor(pt.y),
				z = z - pt.z,
			}
			gpt.x = math.min(math.max(gpt.x, -30), 30)
			gpt.z = math.min(math.max(gpt.z, -30), 30)
			return ni.walk(gpt.x, gpt.y, gpt.z)
		end)
		if not s or not m then
			_G.printError(m2 or m)
		end
	end
	os.sleep(.5)
	while ni.isWalking() do
		os.sleep(0)
	end
end

for _,v in pairs(t) do
	Util.print(v)

	--if v.action == 'walk' then
		walkTo(v.x, v.y, v.z)
	--end
	ni.look(v.yaw, v.pitch)
	if v.action == 'use' then
		ni.use()
		os.sleep(2)
	end
--  os.sleep(v.delay)
 -- os.sleep(2)
 -- read()
end
