-- saves a virtual file to disk

_G.requireInjector(_ENV)

local Util = require('util')

local fs    = _G.fs
local shell = _ENV.shell

local args = { ... }
local fileName = args[1] and
                 shell.resolve(args[1]) or
                 error('Syntax: persist <file name>')

local c = Util.readFile(fileName) or error('Unable to read file')

-- ensure it is writable - if not an error is thrown
Util.writeFile(fileName, '')
fs.delete(fileName)
Util.writeFile(fileName, c)

print('Saved')
