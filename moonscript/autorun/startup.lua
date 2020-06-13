local Map = require('opus.map')

local fs    = _G.fs

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

local function fix(env, args)
	if #args > 0 then
		args[1] = env.shell.resolve(args[1])
	end
	return args
end

_ENV.shell.registerHandler(function(env, command, args)
	if command:match('(.+)%.moon$') then
		return {
			title = fs.getName(command):match('([^%.]+)'),
			path = 'packages/moonscript/moon',
			args = { env.shell.resolveProgram(command), table.unpack(args) },
			load = loadfile,
			env = compatEnv(env),
		}
	end
	command = env.shell.resolveProgram(command) or ''
	return commands[command] and {
		title = fs.getName(command),
		path = command,
		args = fix(env, args),
		load = loadfile,
		env = compatEnv(env),
	}
end)
