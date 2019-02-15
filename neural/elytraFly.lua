-- credit: osmarks https://pastebin.com/ZP9Q1HCT

local Sound = require('sound')

local modules = _G.peripheral.wrap('back')
local os = _G.os
local parallel = _G.parallel

local function run()
  while true do
    local meta = modules.getMetaOwner()

    if not meta.isSneaking and meta.isElytraFlying then

      if meta.pitch < 0 then -- looking up
        modules.launch(meta.yaw, meta.pitch, -meta.pitch / 22.5)
        Sound.play('entity.bobber.throw')

      elseif meta.motionY < -0.5 then -- falling fast
        modules.launch(0, 270, 2)
        Sound.play('entity.bat.takeoff')
      end
      os.sleep(0.1)

    elseif not meta.isSneaking and meta.motionY < -0.8 then
      print('falling...')
      modules.launch(0, 270, 2)
      Sound.play('entity.bat.takeoff')
      os.sleep(0.1)

    else
      os.sleep(0.4)
    end
  end
end

parallel.waitForAny(
  function()
    print('press any key to exit')
    os.pullEvent('char')
  end,
  function()
    while true do
    print('Starting')
    local s, m = pcall(run)
      print(m)
      print('Waiting for 5 seconds before restarting')
      os.sleep(5)
    end
  end)
