local ramfs = require('opus.fs.ramfs')

local fs = _G.fs

local str = 'hello'

local node = fs.mount('test.bin', 'ramfs', 'file')
local file = ramfs.open(node, 'test.bin', 'wb')
for i = 1, 5 do
    file.write(str:sub(i, i))
end
file.close()

node = fs.getNode('test.bin')
file = ramfs.open(node, 'test.bin', 'r')
local s = file.read(5)
file.close()

assert(s == str)

file = ramfs.open(node, 'test.bin', 'w')
file.write(str)
file.close()

node = fs.getNode('test.bin')
file = ramfs.open(node, 'test.bin', 'rb')
s = file.read(5)
file.close()

assert(s == str)
