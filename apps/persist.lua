-- saves a virtual file to disk

_G.requireInjector(_ENV)

local Util = require('util')

local shell = _ENV.shell

local args = { ... }
local fileName = args[1] or error('Syntax: persist <file name>')

local c = Util.readFile(shell.resolve(fileName)) or error('Unable to open file')
Util.writeFile(shell.resolve(fileName), c)

print('Saved')
