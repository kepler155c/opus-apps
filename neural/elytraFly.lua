-- credit: osmarks https://pastebin.com/ZP9Q1HCT

local Sound = require('sound')

local modules = _G.peripheral.wrap('back')
local os = _G.os

while true do
  local meta = modules.getMetaOwner()
  if not meta.isSneaking and meta.isElytraFlying then

  if meta.pitch < 0 then -- looking up
      modules.launch(meta.yaw, meta.pitch, -meta.pitch / 22.5)
      --Sound.play('entity.bobber.throw')

    elseif meta.motionY < -0.5 then -- falling fast
      modules.launch(0, 270, 2)
      Sound.play('entity.bat.takeoff')
    end
    os.sleep(0.1)

  elseif not meta.isSneaking and meta.motionY < -0.8 then
    print('fallling...')
    modules.launch(0, 270, 2)
    Sound.play('entity.bat.takeoff')
    os.sleep(0.1)

  else
    os.sleep(0.4)
  end
end
