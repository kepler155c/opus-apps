local modules = _G.peripheral.wrap('back')
local os = _G.os

print('Based on code from osmarks')
print('https://pastebin.com/ZP9Q1HCT')

local function get_meta()
  return modules.getMetaOwner()
end

while true do
  local meta = get_meta()
  if not meta.isSneaking then
    local power = 4
    if meta.isElytraFlying or meta.isFlying then power = 1 end

    while not meta.isSneaking and meta.isFlying or meta.isElytraFlying do
      meta = get_meta()
      if meta.pitch < 0 then
        modules.launch(meta.yaw, meta.pitch, power)
      end
      os.sleep(0.1)
    end

    if not meta.isSneaking then
      if meta.motionY < -0.8 then
        modules.launch(0, 270, power / 2)
      end
    end
  end

  os.sleep(0.4)
end
