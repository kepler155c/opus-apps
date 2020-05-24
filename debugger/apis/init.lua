--[[
some portions from https://github.com/slembcke/debugger.lua
]]

local fs = _G.fs

local dbg = { }

local function hookBreakpoint(info)
	if dbg.breakpoints then
		for _,v in pairs(dbg.breakpoints) do
			if v.line == info.currentline and v.file == info.short_src then
				return true
			end
		end
	end
end

local function hookFunction(fn)
	return function(info)
		return info.func == fn
	end
end

local function hookStep()
	local co = coroutine.running()
	return function()
		return co == coroutine.running()
	end
end

local function hookStepStacksize(n)
	local co = coroutine.running()
	local i = 2
	while true do
		local info = debug.getinfo(i)
		if not info then
			break
		end
		i = i + 1
	end
	return function()
		if co == coroutine.running() then
			if not debug.getinfo(i - n) then
				return true
			end
		end
	end
end

local function hookStepOut()
	return hookStepStacksize(1)
end

local function hookStepOver()
	return hookStepStacksize(0)
end

local hookEval = function() end

-- Create a table of all the locally accessible variables.
-- Globals are not included when running the locals command
local function local_bindings(offset, stack_inspect_offset)
	offset = offset + 1 + stack_inspect_offset -- add this function to the offset
	local func = debug.getinfo(offset).func
	local bindings = {}

	-- Retrieve the upvalues
	do local i = 1; while true do
		local name, value = debug.getupvalue(func, i)
		if not name then break end
		bindings[name] = value
		i = i + 1
	end end

	-- Retrieve the locals (overwriting any upvalues)
	do local i = 1; while true do
		local name, value = debug.getlocal(offset, i)
		if not name then break end
		bindings[name] = value
		i = i + 1
	end end

	-- Retrieve the varargs (works in Lua 5.2 and LuaJIT)
	local varargs = {}
	do local i = 1; while true do
		local name, value = debug.getlocal(offset, -i)
		if not name then break end
		varargs[i] = value
		i = i + 1
	end end
	if #varargs > 0 then bindings["..."] = varargs end

	return bindings
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
	if info.currentline < 0 then
		return
	end
	if not inHook and hookEval(info) then
		inHook = true

		local offset = 2  -- the offset from this function to the code being debugged
		local inspectOffset = 0

		repeat
			local done = true
			local snapshot = {
				info = debug.getinfo(offset + inspectOffset),
				locals = local_bindings(offset, inspectOffset),
				stack = get_trace(offset, inspectOffset),
			}

			inspectOffset = 0 -- reset

			local cmd, param = dbg.read(snapshot)
			if cmd == 's' then
				hookEval = hookStep()
			elseif cmd == 'n' then
				hookEval = hookStepOver()
			elseif cmd == 'f' then
				hookEval = hookStepOut()
			elseif cmd == 'c' then
				hookEval = hookBreakpoint
			elseif cmd == 'd' then         -- detach
				debug.sethook()
			elseif cmd == 'q' then
				os.exit(0)
			elseif cmd == 'b' then
				dbg.breakpoints = param
				done = false
			elseif cmd == 'i' then
				-- inspect stack at this offset
				inspectOffset = param
				done = false
			end
		until done

		inHook = false
	end
end

debug.sethook(hook, 'l')

-- Expose the debugger's functions
dbg.hook = hook
dbg.exit = function(err) os.exit(err) end
dbg.stopIn = function(fn)
	hookEval = hookFunction(fn)
end
dbg.debugger = nil

dbg.read = function(info)
	_G._pinfo = info

	os.sleep(0)  -- this is important ...
	dbg.debugger:resume('debugger', 'info', info)

	while true do
		local _, cmd, args = os.pullEvent('debugger')
		if cmd == 'b' then
			dbg.breakpoints = args
		else
			return cmd, args
		end
	end
end

return dbg
