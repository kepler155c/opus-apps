local tar = require('compress.tar')
local Util = require('opus.util')

local fs = _G.fs

local files = {
    'test-ramfs.lua',
    'test-tar.lua',
}

fs.mount('packages/tests/test.tar', 'ramfs', 'file')
tar.tar('packages/tests/test.tar', 'packages/tests', files)

fs.mount('packages/tests/untar', 'ramfs', 'directory')
tar.untar('packages/tests/test.tar', 'packages/tests/untar')

local s1 = Util.readFile('packages/tests/test-ramfs.lua', 'r')
local s2 = Util.readFile('packages/tests/untar/test-ramfs.lua', 'r')

assert(s1 == s2)
