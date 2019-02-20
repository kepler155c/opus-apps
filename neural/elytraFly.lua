-- credit: osmarks https://pastebin.com/ZP9Q1HCT

local Sound = require('sound')

local modules = _G.peripheral.wrap('back')
local os = _G.os
local parallel = _G.parallel

if not modules.launch or not modules.getMetaOwner then
  error([[Required:
* Kinetic augment
* Introspection module]])
end

local function run()
  local launchCounter = 0

  while true do
    local meta = modules.getMetaOwner()

    if not meta.isSneaking and meta.isElytraFlying then

      if meta.pitch < 0 then -- looking up
        modules.launch(meta.yaw, meta.pitch, -meta.pitch / 22.5)
        Sound.play('entity.bobber.throw', .6)
        os.sleep(0.1)

      elseif meta.motionY < -0.5 then -- falling fast
        modules.launch(0, 270, -meta.motionY + 1)
        Sound.play('entity.bat.takeoff')
        os.sleep(0)

      else
        os.sleep(0.1)
      end
 
    elseif meta.isSneaking and not meta.isElytraFlying and meta.pitch == -90 then
      if launchCounter < 2 then
        launchCounter = launchCounter + 1
        Sound.play('block.note.pling', .5)
        os.sleep(0.5)

      else
        Sound.play('entity.bobber.throw', 1)
        modules.launch(0, 270, 4)
        os.sleep(0.2)
      end

    elseif not meta.isSneaking and meta.motionY < -0.8 then
      print('falling...')
      modules.launch(0, 270, -meta.motionY + 1)
      Sound.play('entity.bat.takeoff')
      os.sleep(0)

    else
      launchCounter = 0
      os.sleep(0.4)
    end
  end
end

parallel.waitForAny(
  function()
    print('\nFlight control initialized')
    print('\nSneak and look straight up for launch')
    print('\nPress any key to exit')
    os.pullEvent('char')
  end,
  function()
    while true do
    local _, m = pcall(run)
      if m then
        print(m)
      end
      print('Waiting for 5 seconds before restarting')
      os.sleep(5)
    end
  end)
