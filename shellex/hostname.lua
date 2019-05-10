local os = _G.os

local shell = require("shellex.shell")
local args = shell.parse(...)
local hostname = args[1]

if hostname then
  os.setComputerLabel(hostname)
else
  hostname = os.getComputerLabel()
  if hostname then
    print(hostname)
  else
    io.stderr:write("Hostname not set\n")
    return 1
  end
end
