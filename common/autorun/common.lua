local c = function(shell, nIndex, sText)
	if nIndex == 1 then
		return _G.fs.complete(sText, shell.dir(), true, false)
	end
end

_ENV.shell.setCompletionFunction("packages/common/edit.lua", c)
_ENV.shell.setCompletionFunction("packages/common/hexedit.lua", c)

_ENV.shell.registerHandler(function(env, command, args)
	if command:match('^!') then
		return {
			title = 'lua',
			path = table.concat({ command:match('^!(.+)'), table.unpack(args) }, ' '),
			args = args,
			load = function(s)
				return function()
					local fn, m
					local wrapped

					fn = load('return (' ..s.. ')', 'lua', nil, env)

					if fn then
						fn = load('return {' ..s.. '}', 'lua', nil, env)
						wrapped = true
					end

					if fn then
						fn, m = pcall(fn)
						if #m <= 1 and wrapped then
							m = m[1]
						end
					else
						fn, m = load(s, 'lua', nil, env)
						if fn then
							fn, m = pcall(fn)
						end
					end

					if fn then
						if m or wrapped then
							require('opus.util').print(m or 'nil')
						else
							print()
						end
					else
						_G.printError(m)
					end
				end
			end,
			env = env,
		}
	end
end)
