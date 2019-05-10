local shell = _ENV.shell

return {
  execute = function(_, ...) return shell.run(...) end,
  getLastExitCode = function() return 0 end,
}