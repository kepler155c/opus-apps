_G.requireInjector(_ENV)

local Event = require('event')
local UI = require('ui')

redstone.setBundledOutput('bottom', 0)

local function regulate(humidity, heat)
  local heater = heat == 'Up 1' or heat == 'Both 1'
  local lava = heat == 'Both 1'
  local water = humidity == 'Up 1'

  local c = colors.combine(
    lava and colors.green or 0,
    heater and colors.red or 0,
    water and colors.blue or 0)

  redstone.setBundledOutput('bottom', c)
end

function create(alveary, terminal)
  local window = UI.Window({
    alveary = alveary,
    parent = UI.Device({
      device = terminal,
      textScale = 0.5,
      backgroundColor = colors.green
    }),
    progressBar = UI.ProgressBar({
      y = 3,
      x = 2, ex = -2,
    }),
--[[
    heater = UI.Button {
      x = 2, y = -2, width = 7,
      text = 'heater',
    },
    humidifier = UI.Button {
      x = 2, y = -4,
      text = 'Humidify',
    },
    dehumidifier = UI.Button {
      x = 2, y = -6,
      text = 'Dehumidify',
    },
--]]
  })

  function window:draw()
  
    local queen = self.alveary.getQueen()
    if not queen then
      self:clear(colors.black)
      regulate()
    else
      self.backgroundColor = self.alveary.canBreed() and colors.green or colors.red
      self:clear()
      local percDone = 100 - math.floor(queen.health * 100 / queen.maxHealth)
      if not queen.canSpawn then
        percDone = 0
      end
      self.progressBar.value = percDone
      --self.progressBar:draw()
      for _,c in pairs(self.children) do
        c:draw()
      end

      self:centeredWrite(2, queen.displayName)
      self:centeredWrite(4, percDone .. '%')
      self:write(1, 6, 'Generation: ' .. queen.generation)
      self:setCursorPos(1, 7)
      if queen.active then
        regulate(
          queen.active.humidityTolerance,
          queen.active.temperatureTolerance)

        if queen.active.flowerProvider ~= 'Flowers' then
          self:print(queen.active.flowerProvider .. '\n')
        end
        if queen.active.effect ~= 'None' then
          self:print('Effect: ' .. queen.active.effect)
        end
      else
        self:print('(pure)')
      end
    end
  end

  return window
end

local pages = {
  create(device.items, device.monitor),
  --create(device.items_6, device.monitor_22),
  --create(device.items_5, device.monitor_21),
}

Event.onInterval(5, function()
  for _,v in pairs(pages) do
    v:draw()
    v:sync()
  end
end)

UI:pullEvents()

