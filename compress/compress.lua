local LZW  = require('compress.lzw')
local Tar  = require('compress.tar')
local Util = require('opus.util')

local fs    = _G.fs
local shell = _ENV.shell

local TMP_FILE = '.out.tar'

local args  = { ... }
local files = { }

if not args[2] then
	error('Syntax: tar OUTFILE DIR')
end

local file = shell.resolve(args[1])
local dir = shell.resolve(args[2])

local filetype = 'tar'
if file:match('(.+)%.tar$') then
	filetype = 'tar'
elseif file:match('(.+)%.lzw$') then
	filetype = 'lzw'
end

local function recurse(rel)
	local abs = fs.combine(dir, rel)
	for _,f in ipairs(fs.list(abs)) do
		local fullName = fs.combine(abs, f)
		if fs.native.isDir(fullName) then -- skip virtual dirs
			recurse(fs.combine(rel, f))
		else
			table.insert(files, fs.combine(rel, f))
		end
	end
end
recurse('')

if filetype == 'tar' then
	Tar.tar(file, dir, files)

elseif filetype == 'lzw' then
	fs.mount(TMP_FILE, 'ramfs', 'file')
	Tar.tar(TMP_FILE, dir, files)

	local c = Util.readFile(TMP_FILE)
	fs.delete(TMP_FILE)

	c = LZW.compress(c)
	Util.writeFile(file, c)
end

