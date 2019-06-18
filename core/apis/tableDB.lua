local class = require('class')
local Util  = require('util')

local TableDB = class()
function TableDB:init(args)
	local defaults = {
		fileName = '',
		dirty = false,
		data = { },
	}
	Util.merge(defaults, args)
	Util.merge(self, defaults)
end

function TableDB:load()
	local t = Util.readTable(self.fileName)
	if t then
		self.data = t.data or t
	end
end

function TableDB:add(key, entry)
	if type(key) == 'table' then
		key = table.concat(key, ':')
	end
	self.data[key] = entry
	self.dirty = true
end

function TableDB:get(key)
	if type(key) == 'table' then
		key = table.concat(key, ':')
	end
	return self.data[key]
end

function TableDB:remove(key)
	self.data[key] = nil
	self.dirty = true
end

function TableDB:flush()
	if self.dirty then
		Util.writeTable(self.fileName, self.data)
		self.dirty = false
	end
end

return TableDB
