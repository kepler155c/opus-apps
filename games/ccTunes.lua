local Sound = require('sound')

local os = _G.os

local tunes = {
  { sound = 'record.11',      length = '1:11' },
  { sound = 'record.13',      length = '2:58' },
  { sound = 'record.blocks',  length = '5:45' },
  { sound = 'record.cat',     length = '3:05' },
  { sound = 'record.chirp',   length = '3:05' },
  { sound = 'record.far',     length = '2:54' },
  { sound = 'record.mall',    length = '3:17' },
  { sound = 'record.mellohi', length = '1:36' },
  { sound = 'record.stal',    length = '2:30' },
  { sound = 'record.strad',   length = '3:08' },
  { sound = 'record.wait',    length = '3:58' },
  { sound = 'record.ward',    length = '4:11' },
}

while true do
  local song = tunes[math.random(1, #tunes)]
  Sound.play(song.sound)
  local min, sec = song.length:match('(%d+):(%d+)')
  local length = tonumber(min)*60 + tonumber(sec)
  print(string.format('Playing %s (%s)', song.sound, song.length))
  os.sleep(length + 3)
end
