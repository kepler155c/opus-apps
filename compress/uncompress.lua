local DEFLATE = require('compress.deflatelua')
local LZW     = require('compress.lzw')
local Tar     = require('compress.tar')
local Util    = require('opus.util')

local fs    = _G.fs
local io    = _G.io
local shell = _ENV.shell

local TMP_FILE = '.out.tar'

local args = { ... }

if not args[2] then
	error('Syntax: tar FILE DESTDIR')
end

local inFile = shell.resolve(args[1])
local outDir = shell.resolve(args[2])

local s, m = pcall(function()
	if inFile:match('(.+)%.[gG][zZ]$') then
		local fh = io.open(inFile, 'rb') or error('Error opening ' .. inFile)

		fs.mount(TMP_FILE, 'ramfs', 'file')
		local ofh = io.open(TMP_FILE, 'wb')

		DEFLATE.gunzip {input=fh, output=ofh, disable_crc=true}

		fh:close()
		ofh:close()

		local s, m = Tar.untar(TMP_FILE, outDir, true)

		if not s then
			error(m)
		end

	elseif inFile:match('(.+)%.lzw$') then
		local c = Util.readFile(inFile)
		if not c then
			error('Unable to open ' .. inFile)
		end

		fs.mount(TMP_FILE, 'ramfs', 'file')
		Util.writeFile(TMP_FILE, LZW.decompress(c))

		local s, m = Tar.untar(TMP_FILE, outDir, true)

		if not s then
			error(m)
		end

	else
		local s, m = Tar.untar(inFile, outDir)
		if not s then
			error(m)
		end
	end
end)

fs.delete(TMP_FILE)

if not s then
	error(m)
end
