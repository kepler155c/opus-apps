require = requireInjector(getfenv(1))

local Event = require('event')
local UI    = require('ui')

multishell.setTitle(multishell.getCurrent(), 'Music')

local radio = device.drive or error('No drive attached')
if radio.side ~= 'top' and radio.side ~= 'bottom' then
  error('Disk drive must be above or below turtle')
end

if not turtle then
  error('This program can only be run on a turtle')
end

if not device.monitor then
  error('Monitor must be attached (3 wide x 1 tall')
end

local monitor = UI.Device({
  deviceType = 'monitor',
  textScale = 0.5,
})

UI:setDefaultDevice(monitor)

local page = UI.Page({
  volume = 15,
  stationName = UI.Text({
    y = 2,
    x = 2,
    width = monitor.width - 14,
    height = 3,
    backgroundColor = colors.brown,
  }),
  seek = UI.Button({
    y = 7,
    x = 13,
    height = 3,
    event = 'seek',
    text = '  >>  ',
  }),
  play = UI.Button({
    y = 7,
    x = 2,
    height = 3,
    event = 'play',
    text = '> / ll',
  }),
  louder = UI.Button({
    y = 7,
    x = monitor.width - 15,
    width = 3,
    height = 3,
    event = 'louder',
    text = '+',
  }),
  quiet = UI.Button({
    y = 7,
    x = monitor.width - 20,
    event = 'quiet',
    width = 3,
    height = 3,
    text = '-',
  }),
  volumeDisplay = UI.Text({
    y = 3,
    x = monitor.width - 9,
    width = 4,
  }),
  volume1 = UI.Window({
    y = monitor.height - 1,
    x = monitor.width - 8,
    height = 1,
    width = 1,
    color = colors.white
  }),
  volume2 = UI.Window({
    y = monitor.height - 2,
    x = monitor.width - 7,
    height = 2,
    width = 1,
    color = colors.white
  }),
  volume3 = UI.Window({
    y = monitor.height - 3,
    x = monitor.width - 6,
    height = 3,
    width = 1,
    color = colors.yellow
  }),
  volume4 = UI.Window({
    y = monitor.height - 4,
    x = monitor.width - 5,
    height = 4,
    width = 1,
    color = colors.yellow,
  }),
  volume5 = UI.Window({
    y = monitor.height - 5,
    x = monitor.width - 4,
    height = 5,
    width = 1,
    color = colors.orange,
  }),
  volume6 = UI.Window({
    y = monitor.height - 6,
    x = monitor.width - 3,
    height = 6,
    width = 1,
    color = colors.orange,
  }),
  volume7 = UI.Window({
    y = monitor.height - 7,
    x = monitor.width - 2,
    height = 7,
    width = 1,
    color = colors.red,
  }),
  volume8 = UI.Window({
    y = monitor.height - 8,
    x = monitor.width - 1,
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

function page:setVolume(volume, displayOnly)
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

  local actions = {
    top = {
      suck = turtle.suckUp,
      drop = turtle.dropUp,
    },
    bottom = {
      suck = turtle.suckDown,
      drop = turtle.dropDown,
    },
  }

  local slot = turtle.selectOpenSlot()
  actions[radio.side].suck()
  repeat
    slot = slot + 1
    if (slot > 16) then
      slot = 1
    end
  until turtle.getItemCount(slot) >= 1
  turtle.select(slot)
  actions[radio.side].drop()
  self:updateStationName()
end

function page:play(onOff)
  self.playing = onOff
  if self.playing then

    if not radio.hasAudio() then
      self:seek()
    end

    self:updateStationName()
    radio.playAudio()

    Event.addNamedTimer('songTimer', 180, false, function()
      if self.playing then
        self:seek()
        self:play(true)
        self:sync()
      end
    end)

  else
    radio.stopAudio()
  end
end

function page.stationName:draw()
  self:clear()
  self:centeredWrite(2, self.value)
end

function page:updateStationName()
  local title = radio.getAudioTitle()
 
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

turtle.status = 'Jamming'
UI:pullEvents()
turtle.status = 'idle'
page:play(false)

UI.term:reset()
