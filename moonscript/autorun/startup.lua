local Map = require('opus.map')

local fs    = _G.fs
local shell = _ENV.shell

local commands = Map.transpose {
	'packages/moonscript/moon',
	'packages/moonscript/moonc'
}

local function compatEnv(source)
	local env = Map.shallowCopy(source._G)
	Map.merge(env, source)
	env._G = env
	_G.requireInjector(env, 'packages/moonscript')
	return env
end

shell.registerHandler(function(args, env)
	if args[1]:match('(.+)%.moon$') then
		return {
			title = fs.getName(args[1]):match('([^%.]+)'),
			path = 'packages/moonscript/moon',
			args = args,
			load = loadfile,
			env = compatEnv(env),
		}
	end
	local command = shell.resolveProgram(args[1]) or ''
	return commands[command] and {
		title = fs.getName(command),
		path = command,
		args = { table.unpack(args, 2) },
		load = loadfile,
		env = compatEnv(env),
	}
end)
