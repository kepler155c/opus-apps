local tty = require("shellex.tty")

local args = {...}
local gpu = tty.gpu()
io.write("Press 'Ctrl-C' to exit\n")
local events = { }
for _, e in pairs(args) do
	events[e] = true
end
--pcall(function()
	repeat
		local evt = table.pack(os.pullEventRaw())
		if #args == 0 or events[evt[1]] then
			gpu.setForeground(0xCC2200)
			io.write("[" .. math.floor(os.clock("utc")) .. "] ")
			gpu.setForeground(0x44CC00)
			io.write(tostring(evt[1]) .. string.rep(" ", math.max(12 - #tostring(evt[1]), 0) + 1))
			gpu.setForeground(0xB0B00F)
			io.write(tostring(evt[2]) .. string.rep(" ", 37 - #tostring(evt[2])))
			gpu.setForeground(0xFFFFFF)
			if evt.n > 2 then
				for i = 3, evt.n do
					io.write("  " .. tostring(evt[i]))
				end
			end

			io.write("\n")
		end
	until evt[1] == "terminate"
--end)

gpu.setForeground(0xFFFFFF)

