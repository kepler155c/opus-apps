-- a port of LuaFileSystem
-- https://keplerproject.github.io/luafilesystem/manual.html

local fs    = _G.fs
local shell = _ENV.shell

local lfs = {
	_VERSION = '1.8.0.computercraft'
}

-- lfs.attributes (filepath [, request_name | result_table])
-- Returns a table with the file attributes corresponding to filepath (or nil followed
-- by an error message and a system-dependent error code in case of error). If the second
-- optional argument is given and is a string, then only the value of the named attribute
-- is returned (this use is equivalent to lfs.attributes(filepath)[request_name], but the
-- table is not created and only one attribute is retrieved from the O.S.). if a table is
-- passed as the second argument, it (result_table) is filled with attributes and returned
-- instead of a new table. The attributes are described as follows; attribute mode is a
-- string, all the others are numbers, and the time related attributes use the same time
-- reference of os.time:
function lfs.attributes(path, request_name)
	path = shell.resolve(path)

	local s, fsattr = pcall(fs.attributes, path)
	if not s then
		return nil, fsattr, 1
	end

	local attributes = type(request_name) == 'table' and request_name or { }

	-- on Unix systems, this represents the device that the inode resides on.
	-- On Windows systems, represents the drive number of the disk containing the file
	attributes.dev = fs.getDrive(path)

	-- on Unix systems, this represents the inode number.
	-- On Windows systems this has no meaning
	attributes.ino = nil

	--string representing the associated protection mode
	-- (the values could be file, directory, link, socket, named pipe,
	-- char device, block device or other)
	attributes.mode = fsattr.isDir and 'directory' or 'file'

	-- number of hard links to the file
	attributes.nlink = 0

	-- user-id of owner (Unix only, always 0 on Windows)
	attributes.uid = 0

	-- group-id of owner (Unix only, always 0 on Windows)
	attributes.gid = 0

	-- on Unix systems, represents the device type, for special file inodes.
	-- On Windows systems represents the same as dev
	attributes.rdev = attributes.dev

	-- time of last access
	attributes.access = fsattr.modification

	-- time of last data modification
	attributes.modification = fsattr.modification

	-- time of last file status change
	attributes.change = fsattr.modification

	-- file size, in bytes
	attributes.size = fsattr.size

	-- file permissions string
	local perm = (fs.isDir or fs.isReadOnly(path)) and 'r-x' or 'rwx'
	attributes.permissions = perm .. perm .. perm

	-- block allocated for file; (Unix only)
	attributes.blocks = nil

	-- optimal file system I/O blocksize; (Unix only)
	attributes.blksize = nil

	return type(request_name) ~= 'string' and attributes or attributes[request_name]
end

-- lfs.chdir (path)
-- Changes the current working directory to the given path.
-- Returns true in case of success or nil plus an error string.
function lfs.chdir(path)
	path = shell.resolve(path)
	if fs.isDir(path) then
		shell.setDir(path)
		return true
	end
	return nil, path .. ': No such directory'
end

-- lfs.currentdir ()
-- Returns a string with the current working directory or nil plus an error string.
function lfs.currentdir()
	return '/' .. shell.dir()
end

-- iter, dir_obj = lfs.dir (path)
-- Lua iterator over the entries of a given directory.
-- Each time the iterator is called with dir_obj it returns a directory
-- entry's name as a string, or nil if there are no more entries.
-- You can also iterate by calling dir_obj:next(), and explicitly close the
-- directory before the iteration finished with dir_obj:close().
-- Raises an error if path is not a directory.
function lfs.dir(path)
	path = shell.resolve(path)
	local set = fs.list(path)
	local iter = function()
		local key, value = next(set)
		set[key or false] = nil
		return value
	end
	return iter, {
		valid = true,
		closed = false,
		next = function(self)
			if not self.valid then
				error('file iterator invalid')
			end
			local n = iter()
			if not n then
				self.valid = false
			end
			return n
		end,
		close = function(self)
			if self.closed then
				error('file iterator invalid')
			end
			self.closed = true
			self.valid = false
		end,
	}
end

-- lfs.link (old, new[, symlink])
-- Creates a link. The first argument is the object to link to and the second is the
-- name of the link. If the optional third argument is true, the link will by a symbolic
-- link (by default, a hard link is created).
function lfs.link(old, new, symlink)
	if not symlink then
		return false
	end
	-- hard links are not supported in vfs :(
	old = shell.resolve(old)
	new = shell.resolve(new)
	return not not fs.mount(new, 'linkfs', old)
end

-- lfs.mkdir (dirname)
-- Creates a new directory. The argument is the name of the new directory.
-- Returns true in case of success or nil, an error message and a system-dependent
-- error code in case of error.
function lfs.mkdir(dirname)
	dirname = shell.resolve(dirname)
	if fs.exists(fs.getDir(dirname)) then
		fs.makeDir(dirname)
		if fs.isDir(dirname) then
			return true
		end
	end
	return nil, dirname .. ': Unable to create directory', 1
end

-- lfs.rmdir (dirname)
-- Removes an existing directory. The argument is the name of the directory.
-- Returns true in case of success or nil, an error message and a system-dependent
-- error code in case of error.
function lfs.rmdir(dirname)
	dirname = shell.resolve(dirname)
	if not fs.exists(dirname) or not fs.isDir(dirname) then
		return false, dirname .. ': Not a directory', 1
	end
	pcall(fs.delete, dirname)
	return not fs.exists(dirname) or false, dirname .. ': Unable to remove directory', 1
end

-- lfs.setmode (file, mode)
-- Sets the writing mode for a file. The mode string can be either "binary" or "text".
-- Returns true followed the previous mode string for the file, or nil followed by an
-- error string in case of errors. On non-Windows platforms, where the two modes are
-- identical, setting the mode has no effect, and the mode is always returned as binary.
function lfs.setmode(file)
	if tostring(file) == 'file (closed)' then
		error('closed file')
	end
	return true, 'binary'
end

-- lfs.symlinkattributes (filepath [, request_name])
-- Identical to lfs.attributes except that it obtains information about the link itself
-- (not the file it refers to). It also adds a target field, containing the file name that
-- the symlink points to. On Windows this function does not yet support links, and is
-- identical to lfs.attributes.
function lfs.symlinkattributes(filepath, request_name)
	filepath = shell.resolve(filepath)

	local target = fs.resolve(filepath)
	local attribs = lfs.attributes('/' .. target)
	if filepath ~= target then
		attribs.target = '/' .. target
		attribs.mode = 'link'
	end

	return request_name and attribs[request_name] or attribs
end

-- lfs.touch (filepath [, atime [, mtime]])
-- Set access and modification times of a file. This function is a bind to utime function.
-- The first argument is the filename, the second argument (atime) is the access time, and
-- the third argument (mtime) is the modification time. Both times are provided in seconds
-- (which should be generated with Lua standard function os.time). If the modification time
-- is omitted, the access time provided is used; if both times are omitted, the current time
-- is used.
-- Returns true in case of success or nil, an error message and a system-dependent error
-- code in case of error.
function lfs.touch(filename, atime, mtime)
	mtime = mtime or atime
	filename = shell.resolve(filename)

	if atime or mtime then
		error('setting access/modification time is not supported')
	end

	-- cc does not suport setting atime/mtime
	-- error('lfs.touch not supported')
	if not fs.exists(filename) then
		local f = fs.open(filename, 'w')
		if f then
			f.close()
		end
	end
end

return lfs
