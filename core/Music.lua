_G.requireInjector()

local Event = require('event')
local UI    = require('ui')

local colors     = _G.colors
local peripheral = _G.peripheral

local speaker = peripheral.find('speaker') or
  error('Speaker must be attached')

UI:configure('Music', ...)

UI.Button.defaults.backgroundFocusColor = colors.gray

local songs = {
  { record = 'record.11', title = '11' },
  { record = 'record.13', title = '13' },
  { record = 'record.block', title = 'Block' },
  { record = 'record.cat', title = 'Cat' },
  { record = 'record.chirp', title = 'Chirp' },
  { record = 'record.far', title = 'Faf' },
  { record = 'record.mall', title = 'Mall' },
  { record = 'record.mellohi', title = 'Mellohi' },
  { record = 'record.stal', title = 'Stal' },
  { record = 'record.strad', title = 'Strad' },
  { record = 'record.wait', title = 'Wait' },
  { record = 'record.ward', title = 'Ward' },
}
local songNo = 1

local page = UI.Page({
  volume = 15,
  stationName = UI.Text({
    y = 2,
    x = 2,
    ex = -14,
    height = 3,
    backgroundColor = colors.black,
  }),
  play = UI.Button({
    y = -4,
    x = 2,
    height = 3,
    event = 'play',
    text = '> / ll',
  }),
  seek = UI.Button({
    y = -4,
    x = 12,
    height = 3,
    event = 'seek',
    text = '  >>  ',
  }),
  quiet = UI.Button({
    y = -4,
    x = -19,
    event = 'quiet',
    width = 3,
    height = 3,
    text = '-',
  }),
  louder = UI.Button({
    y = -4,
    x = -14,
    width = 3,
    height = 3,
    event = 'louder',
    text = '+',
  }),
  volumeDisplay = UI.Text({
    y = 3,
    x = -9,
    width = 4,
  }),
  volume1 = UI.Window({
    y = -2,
    x = -9,
    height = 1,
    width = 1,
    color = colors.white
  }),
  volume2 = UI.Window({
    y = -3,
    x = -8,
    height = 2,
    width = 1,
    color = colors.white
  }),
  volume3 = UI.Window({
    y = -4,
    x = -7,
    height = 3,
    width = 1,
    color = colors.yellow
  }),
  volume4 = UI.Window({
    y = -5,
    x = -6,
    height = 4,
    width = 1,
    color = colors.yellow,
  }),
  volume5 = UI.Window({
    y = -6,
    x = -5,
    height = 5,
    width = 1,
    color = colors.orange,
  }),
  volume6 = UI.Window({
    y = -7,
    x = -4,
    height = 6,
    width = 1,
    color = colors.orange,
  }),
  volume7 = UI.Window({
    y = -8,
    x = -3,
    height = 7,
    width = 1,
    color = colors.red,
  }),
  volume8 = UI.Window({
    y = -9,
    x = -2,
    height = 8,
    width = 1,
    color = colors.red,
  })
})

page.volumeControls = {
  page.volume1, page.volume2,
  page.volume3, page.volume4,
  page.volume5, page.volume6,
  page.volume7, page.volume8,
}

function page:eventHandler(event)
  if event.type == 'play' then
    self:play(not self.playing)
  elseif event.type == 'seek' then
    self:seek()
    self:play(true)
  elseif event.type == 'louder' then
    if self.playing then
      self:setVolume(self.volume + 1)
    end
  elseif event.type == 'quiet' then
    if self.playing then
      self:setVolume(self.volume - 1)
    end
  end
end

function page:setVolume(volume)
  volume = math.min(volume, 15)
  volume = math.max(volume, 1)
  self.volume = volume
  volume = math.ceil(volume / 2)

  for i = 1, volume do
    self.volumeControls[i].backgroundColor =
      self.volumeControls[i].color
  end
  for i = volume + 1, #self.volumeControls do
    self.volumeControls[i].backgroundColor = colors.black
  end
  for i = 1, #self.volumeControls do
    self.volumeControls[i]:clear()
  end
  local percent = math.ceil(self.volume / 15 * 100)
  self.volumeDisplay.value = percent .. '%'
  self.volumeDisplay:draw()
end

function page:seek()
  songNo = songNo + 1
  if songNo > #songs then
    songNo = 1
  end
  self:updateStationName()
end

function page:play(onOff)
  self.playing = onOff
  if self.playing then
    self:updateStationName()
    speaker.playSound(songs[songNo])

    Event.addNamedTimer('songTimer', 180, false, function()
      if self.playing then
        self:seek()
        self:play(true)
        self:sync()
      end
    end)

  else
    --radio.stopAudio()
  end
end

function page.stationName:draw()
  self:clear()
  self:centeredWrite(2, self.value)
end

function page:updateStationName()
  local title = songs[songNo].title

  if title then
    self.stationName.value = title
    self.stationName:draw()
  end
end

Event.onInterval(1, function()
  if not page.playing then
    if page.stationName.value == '' then
      page:updateStationName()
    else
      page.stationName.value = ''
      page.stationName:draw()
    end
    page:sync()
  end
end)

page:play(true)
page:setVolume(page.volume, true)

UI:setPage(page)

UI:pullEvents()
page:play(false)

UI.term:reset()
