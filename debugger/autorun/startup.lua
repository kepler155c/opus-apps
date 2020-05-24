local completion = require('cc.shell.completion')

_ENV.shell.setCompletionFunction("packages/debugger/debug.lua",
	completion.build(completion.program))
