local DEFLATE = require('compress.deflatelua')
local LZW     = require('opus.compress.lzw')
local Tar     = require('opus.compress.tar')
local Util    = require('opus.util')

local io    = _G.io
local shell = _ENV.shell

local args = { ... }

if not args[2] then
	error('Syntax: tar FILE DESTDIR')
end

local inFile = shell.resolve(args[1])
local outDir = shell.resolve(args[2])

if inFile:match('(.+)%.[gG][zZ]$') then
	-- uncompress a file created with: tar czf ...
	local fh = io.open(inFile, 'rb') or error('Error opening ' .. inFile)

	local t = { }
	local function writer(b)
		table.insert(t, b)
	end

	DEFLATE.gunzip {input=fh, output=writer, disable_crc=true}

	fh:close()

	local s, m = Tar.untar_string(string.char(table.unpack(t)), outDir, true)

	if not s then
		error(m)
	end

elseif inFile:match('(.+)%.tar%.lzw$') then
	local c = Util.readFile(inFile, 'rb')
	if not c then
		error('Unable to open ' .. inFile)
	end

	local s, m = Tar.untar_string(LZW.decompress(c), outDir, true)

	if not s then
		error(m)
	end

else
	local s, m = Tar.untar(inFile, outDir, true)
	if not s then
		error(m)
	end
end
