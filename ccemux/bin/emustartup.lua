local ccemux
ccemux = _G.ccemux
local fs
fs = _G.fs
local peripheral
peripheral = _G.peripheral
local unserialize
unserialize = _G.textutils.unserialize
local CONFIG = 'usr/config/ccemux'
if ccemux and fs.exists(CONFIG) then
  local f = fs.open(CONFIG, 'r')
  local c = unserialize(f.readAll())
  f.close()
  for k, v in pairs(c) do
    if not peripheral.getType(k) then
      ccemux.attach(k, v.type, v.args)
      print(k)
    end
  end
end
