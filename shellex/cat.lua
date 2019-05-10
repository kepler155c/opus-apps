local shell = require("shellex.shell")
local fs = require("shellex.filesystem")

local args = shell.parse(...)
local ec = 0
if #args == 0 then
  args = {"-"}
end

for i = 1, #args do
  local arg = shell.resolve(args[i])
  if fs.isDirectory(arg) then
    io.stderr:write(string.format('cat %s: Is a directory\n', arg))
    ec = 1
  else
    local file, reason = fs.open(arg)
    if not file then
      io.stderr:write(string.format("cat: %s: %s\n", args[i], tostring(reason)))
      ec = 1
    else
      local chunk = file.readAll()
      file:close()
      if chunk then
        io.write(chunk)
        io.write('\n')
      end
    end
  end
end

return ec