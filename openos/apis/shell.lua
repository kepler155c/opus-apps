local Util = require('util')

local shell = _ENV.shell

return {
  getWorkingDirectory = shell.dir,
  resolve = shell.resolve,
  parse = Util.parse,
}
