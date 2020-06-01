-- see: https://github.com/luarocks/luarocks/blob/master/src/luarocks/tools/tar.lua

-- TODO: support normal tar syntax -- tar xvf

local DEFLATE = require('compress.deflatelua')
local tar     = require('compress.tar')

local fs    = _G.fs
local io    = _G.io
local shell = _ENV.shell

local args = { ... }

if not args[2] then
	error('Syntax: tar FILE DESTDIR')
end

local inFile = shell.resolve(args[1])
local outDir = shell.resolve(args[2])

if inFile:match('(.+)%.[gG][zZ]$') then
	local TMP_FILE = '.out.tar'

	local fh = io.open(inFile, 'rb') or error('Error opening ' .. inFile)

	fs.mount(TMP_FILE, 'ramfs', 'file')
	local ofh = io.open(TMP_FILE, 'wb')

	DEFLATE.gunzip {input=fh, output=ofh, disable_crc=true}

	fh:close()
	ofh:close()

	local s, m = tar.untar(TMP_FILE, outDir, true)

	fs.delete(TMP_FILE)

	if not s then
		error(m)
	end
else
	local s, m = tar.untar(inFile, outDir)
	if not s then
		error(m)
	end
end
