-- this code is loaded into the code being debugged
-- some portions from https://github.com/slembcke/debugger.lua

local fs = _G.fs

local dbg = { }

local function breakpointHook(info)
	if dbg.breakpoints then
		for _,v in pairs(dbg.breakpoints) do
			if v.line == info.currentline and v.file == info.short_src then
				return not v.disabled
			end
		end
	end
end

local function functionHook(fn)
	return function(info)
		return info.func == fn
	end
end

local function stepHook()
	local co = coroutine.running()
	return function(info)
		return co == coroutine.running()
			or breakpointHook(info)
	end
end

local function stackSizeHook(n)
	local co = coroutine.running()
	local i = 2
	while true do
		local info = debug.getinfo(i)
		if not info then
			break
		end
		i = i + 1
	end
	return function(info)
		return co == coroutine.running()
			and not debug.getinfo(i - n)
			or breakpointHook(info)
	end
end

local function stepOutHook()
	return stackSizeHook(1)
end

local function stepOverHook()
	return stackSizeHook(0)
end

local hookEval = function() end

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

local inHook = false

local function hook()
	local info = debug.getinfo(2)

	if not inHook and hookEval(info) then
		inHook = true

		local inspectOffset = 0

		repeat
			local done = true

			local snapshot = {
				info = debug.getinfo(2 + inspectOffset),
				locals = local_bindings(2, inspectOffset),
				stack = get_trace(2, inspectOffset),
			}
			inspectOffset = 0 -- reset

			os.queueEvent('debuggerX', dbg.debugger.uid, snapshot)

			local e, cmd, param
			repeat
				e, cmd, param = os.pullEvent('debugger')
			until e == 'debugger'

			if cmd == 's' then
				hookEval = stepHook()
			elseif cmd == 'n' then
				hookEval = stepOverHook()
			elseif cmd == 'f' then
				hookEval = stepOutHook()
			elseif cmd == 'c' then
				hookEval = breakpointHook
			elseif cmd == 'i' then
				-- get snapshot of stack at this offset
				inspectOffset = param
				done = false
			else
				os.sleep(1)
				done = false
			end
		until done

		inHook = false
	end
end

function dbg.call(fn, ...)
	local args = { ... }
	return xpcall(
		function()
			fn(table.unpack(args))
		end,
		function(err)
			hookEval = stepHook()

			-- An error has occurred
			return err
		end)
end

_ENV.coroutine = setmetatable({

	create = function(fn)
		local co = _G.coroutine.create(function(...)
			local r = { dbg.call(fn, ...) }

			if not r[1] then
				error(r[2], -1)
			end

			return table.unpack(r, 2)
		end)

		debug.sethook(co, hook, 'l')
		return co
	end
	--[[
	create = function(f)
		local co = _G.coroutine.create(f)
		debug.sethook(co, hook, 'l')
		return co
	end
	]]
}, { __index = coroutine })

debug.sethook(hook, 'l')

-- Expose the debugger's functions
dbg.stopIn = function(fn)
	hookEval = functionHook(fn)
end
dbg.debugger = nil

return dbg
