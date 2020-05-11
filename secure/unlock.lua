-- add this file to the preload section of .startup.boot
-- example:
-- {
--   preload = { 'packages/secure/unlock.lua' },
--   ...

package.path = '/sys/modules/?.lua;' .. package.path

local Security = require('opus.security')
local SHA      = require('opus.crypto.sha2')
local Terminal = require('opus.terminal')

local term = _G.term

term.setCursorPos(1, 1)
term.clear()

repeat
	local s, m = pcall(function()
		local password = Terminal.readPassword('Enter password: ')

		if password and Security.verifyPassword(SHA.compute(password)) then
			return true
		end
		error('Invalid password')
	end)
	if not s and m then
		_G.printError(m)
	end
until s
