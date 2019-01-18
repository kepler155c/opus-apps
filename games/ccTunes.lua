local Sound = require('sound')

local os = _G.os

local tunes = {
  'record.11',
  'record.13',
  'record.blocks',
  'record.cat',
  'record.chirp',
  'record.far',
  'record.mall',
  'record.mellohi',
  'record.stal',
  'record.strad',
  'record.wait',
  'record.ward',
}

while true do
  Sound.play(tunes[math.random(1, #tunes)])
  os.sleep(120)
end
