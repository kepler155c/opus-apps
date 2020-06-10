-- this code is loaded into the code being debugged
-- some portions from https://github.com/slembcke/debugger.lua

local fs = _G.fs

local dbg = {
	hooks = { },
	waits = { },
	breakpoints = nil,
}

local function breakpointHook(depth, lineNo)
	if dbg.breakpoints then
		local info
		for _,v in ipairs(dbg.breakpoints) do
			if v.line == lineNo then
				if not info then
					info = debug.getinfo(depth)
				end
				if (v.file == info.short_src or v.bfile == info.short_src) then
					return not v.disabled
				end
			end
		end
	end
end

local function functionHook(fn)
	return function()
		return debug.getinfo(3).func == fn
	end
end

local function stepHook()
	return function()
		return true
	end
end

local function stackSizeHook(n)
	local i = 2
	while true do
		local info = debug.getinfo(i)
		if not info then
			break
		end
		i = i + 1
	end
	return function(depth, lineNo)
		return not debug.getinfo(i - n)
			or breakpointHook(depth + 1, lineNo)
	end
end

local function stepOutHook()
	return stackSizeHook(1)
end

local function stepOverHook()
	return stackSizeHook(0)
end

-- Create a table of all the locally accessible variables.
local function local_bindings(offset, stack_inspect_offset)
	offset = offset + 1 + stack_inspect_offset -- add this function to the offset
	local func = debug.getinfo(offset).func
	local bindings = { }

	-- Retrieve the upvalues
	do local i = 1; while true do
		local name, value = debug.getupvalue(func, i)
		if not name then break end
		bindings[name] = { type = 'U', raw = value }
		i = i + 1
	end end

	-- Retrieve the locals (overwriting any upvalues)
	do local i = 1; while true do
		local name, value = debug.getlocal(offset, i)
		if not name then break end
		bindings[name] = { type = 'L', raw = value }
		i = i + 1
	end end

	-- Retrieve the varargs (works in Lua 5.2 and LuaJIT)
	local varargs = { }
	do local i = 1; while true do
		local name, value = debug.getlocal(offset, -i)
		if not name then break end
		varargs[i] = value
		i = i + 1
	end end
	if #varargs > 0 then
		bindings["..."] = { type = 'V', value = varargs }
	end

	local t = { }
	for k,v in pairs(bindings) do
		if k ~= '(*temporary)' then
			v.name = k
			v.value = tostring(v.raw)
			--if type(v.raw) == 'table' and not next(v.raw) then
			--	v.value = 'table: (empty)'
			--end
			table.insert(t, v)
		end
	end

	return t
end

local function get_trace(offset, stack_inspect_offset)
	local function format_loc(file, line) return file..":"..line end
	local function format_stack_frame_info(info)
		local filename = info.source:match("@(.*)")
		local source = filename and fs.getName(filename) or info.short_src
		local namewhat = (info.namewhat == "" and "chunk at" or info.namewhat)
		local name = (info.name and "'"..info.name.."'" or format_loc(source, info.linedefined))
		return format_loc(source, info.currentline).." in "..namewhat.." "..name
	end

	offset = offset + 1 -- add this function to the offset
	local t = { }
	local i = 0
	while true do
		local info = debug.getinfo(offset + i)
		if not info then break end
		t[i] = {
			index = i,
			current = (i == stack_inspect_offset),
			desc = format_stack_frame_info(info),
			info = info,
		}
		i = i + 1
	end

	return t
end

local function hook(_, lineNo)
	local h = dbg.hooks[coroutine.running()]

	if h and h.eval(3, lineNo) then
		local inspectOffset = 0

		repeat
			local done = true

			local snapshot = {
				info = debug.getinfo(2 + inspectOffset),
				locals = local_bindings(2, inspectOffset),
				stack = get_trace(2, inspectOffset),
			}
			inspectOffset = 0 -- reset

			table.insert(dbg.waits, h)
			while dbg.waits[1] ~= h do
				os.sleep(.1)
			end
			local cmd, param = dbg.read(snapshot)

			table.remove(dbg.waits, 1)

			if cmd == 's' then
				h.eval = stepHook()
			elseif cmd == 'n' then
				h.eval = stepOverHook()
			elseif cmd == 'f' then
				h.eval = stepOutHook()
			elseif cmd == 'c' then
				h.eval = breakpointHook
			elseif cmd == 'i' then
				-- get snapshot of stack at this offset
				inspectOffset = param
				done = false
			else
				done = false
			end
		until done
	end
end

function dbg.call(fn, ...)
	local args = { ... }
	return xpcall(
		function()
			return fn(table.unpack(args))
		end,
		function(err)
			dbg.hooks[coroutine.running()].eval = stepHook()

			-- An error has occurred
			return err
		end)
end

dbg.stopIn = function(fn)
	dbg.hooks[coroutine.running()].eval = functionHook(fn)
end

_ENV.coroutine = setmetatable({
	create = function(fn)
		local co = _G.coroutine.create(function(...)
			local r = { dbg.call(fn, ...) }

			dbg.hooks[coroutine.running()] = nil
			if not r[1] then
				error(r[2], -1)
			end

			return table.unpack(r, 2)
		end)

		dbg.hooks[co] = {
			co = co,
			eval = breakpointHook,
		}
		debug.sethook(co, hook, 'l')
		return co
	end
}, { __index = coroutine })

dbg.hooks[coroutine.running()] = {
	co = coroutine.running(),
	eval = function() return false end,
}

debug.sethook(hook, 'l')
return dbg
