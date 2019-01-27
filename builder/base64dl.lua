local Base64 = require('builder.base64')

local http  = _G.http
local os    = _G.os
local shell = _ENV.shell

local args = { ... }

if not args[2] then
	error('Syntax: base64dl <file name> <url>')
end

local c = http.get(args[2])

if not c then
	error('unable to open url')
end

local data = c.readAll()
c.close()

print('size: ' .. #data)
local decoded = Base64.decode(data)
print('decoded: ' .. #decoded)

local file = io.open(shell.resolve(args[1]), "wb")
if not file then
	error('Unable to open ' .. args[1], 2)
end
for k,b in ipairs(decoded) do
	if (k % 1000) == 0 then
		os.sleep(0)
	end
	file:write(b)
end

file:close()
print('done')
