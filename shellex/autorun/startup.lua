local fs       = _G.fs
local os       = _G.os
local settings = _G.settings

settings.set('LS_COLORS', "di=0;36:fi=0:ln=0;33:*.lua=0;32")

function os.setenv(k, v)
  settings.set(k, v)
end
function os.getenv(k)
  return settings.get(k)
end

fs.mount('rom/programs/list.lua', 'linkfs', 'packages/shellex/ls.lua')
fs.mount('rom/programs/delete.lua', 'linkfs', 'packages/shellex/rm.lua')
fs.mount('rom/programs/copy.lua', 'linkfs', 'packages/shellex/cp.lua')
fs.mount('rom/programs/move.lua', 'linkfs', 'packages/shellex/mv.lua')
