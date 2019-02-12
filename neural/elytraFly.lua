-- credit: osmarks https://pastebin.com/ZP9Q1HCT

local modules = _G.peripheral.wrap "back"
local os = _G.os

local function get_meta()
  return modules.getMetaOwner()
end

while true do
  local meta = get_meta()
  local power = 4
  if meta.isElytraFlying or meta.isFlying then power = 1 end

  while meta.isSneaking or meta.isFlying or meta.isElytraFlying do
    meta = get_meta()
    modules.launch(meta.yaw, meta.pitch, power)
    os.sleep(0.1)
  end

  if meta.motionY < -0.8 then
      modules.launch(0, 270, power / 2)
  end

  os.sleep(0.4)
end
