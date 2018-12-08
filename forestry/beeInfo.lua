_G.requireInjector(_ENV)

local Event = require('event')
local UI = require('ui')
local Util = require('util')

local chest = peripheral.wrap('bottom')

local data
local monitor = UI.Device({
  deviceType = 'monitor',
  textScale = .5
})

UI:setDefaultDevice(monitor)

local breedingPage = UI.Page({
  titleBar = UI.TitleBar(),
  grid = UI.Grid({
    columns = {
      { heading  = '  ', key = 'chance' },
      { heading = 'Princess', key = 'princess', },
      { heading = 'Drone', key = 'drone' },
      { heading = 'Result', key = 'result', },
    },
    y = 2, ey = -8,
    sortColumn = 'result',
    autospace = true
  }),
  specialConditions = UI.Window({
    backgroundColor = colors.red,
    y = -7,
    height = 2
  }),
  buttons = UI.Window({
    y = monitor.height - 4,
    width = monitor.width,
    height = 5,
    backgroundColor = colors.gray,
    prevButton = UI.Button({
      event = 'previous',
      x = 2,
      y = 2,
      height = 3,
      width = 5,
      text = ' < '
    }),
    resetButton = UI.Button({
      event = 'clear',
      x = 8,
      y = 2,
      height = 3,
      width = monitor.width - 14,
      text = 'Clear'
    }),
    nextButton = UI.Button({
      event = 'next',
      x = monitor.width - 5,
      y = 2,
      height = 3,
      width = 5,
      text = ' > '
    })
  })
})

function breedingPage:getBreedingData()
  self.grid.values = { }
  local stacks = chest.getAllStacks(false)
  local stack = stacks[1]
  self.titleBar.title = stack.individual.displayName
  if stack.individual.active then
  end
  for _,d in pairs(data) do
    if d.allele1 == stack.individual.displayName or
       d.allele2 == stack.individual.displayName then
      local ind = ''
      if d.specialConditions then
        ind = '*'
      end
      table.insert(self.grid.values, {
        princess = d.allele1 .. ind,
        drone = d.allele2,
        result = d.result,
        chance = d.chance .. '%',
        specialConditions = d.specialConditions
      })
    end
  end
  self.grid.index = 1
  self.grid:adjustWidth()
  self.grid:update()
  self:draw()
  self:sync()
end

function breedingPage.specialConditions:draw()
  local selected = self.parent.grid:getSelected()
  if selected and selected.specialConditions then
    local sc = ''
    if selected.specialConditions then
      for _,v in ipairs(selected.specialConditions) do
        if sc ~= '' then
          sc = sc .. ', '
        end
        sc = sc .. v
      end
    end
    self:clear()
    self:setCursorPos(2, 1)
    self:print(sc)
  else
    self:clear(colors.red)
  end
end

function breedingPage.grid:draw()
  UI.Grid.draw(self)
  self.parent.specialConditions:draw()
end

function breedingPage:eventHandler(event)
  if event.type == 'next' then
    self.grid:setPage(self.grid:getPage() + 1)
  elseif event.type == 'previous' then
    self.grid:setPage(self.grid:getPage() - 1)
  elseif event.type == 'clear' then
    self.grid:setTable({})
    self.grid:draw()
  elseif event.type == 'grid_focus_row' then
    self.specialConditions:draw()
  else
    return UI.Page.eventHandler(self, event)
  end
  return false
end

Event.on('turtle_inventory', function()
  local slot = turtle.selectSlotWithQuantity(1)

  if slot then
    turtle.dropDown()
    breedingPage:getBreedingData()
    turtle.suckDown()
    turtle.drop()
  end
  
end)

if not fs.exists('.bee.data') then
  local p = peripheral.wrap("back")
  local data = p.getBeeBreedingData()
  local t = { }
  for _,d in pairs(data) do
    d = Util.shallowCopy(d)
    if type(d.specialConditions) == 'string' then
      if d.specialConditions == '[]' then
        d.specialConditions = ''
      end
    end
    if #d.specialConditions == 0 then
      d.specialConditions = nil
    else
      d.specialConditions = Util.shallowCopy(d.specialConditions)
    end
    table.insert(t, d)
  end
  Util.writeTable('.bee.data', t)
else
  data = Util.readTable('.bee.data')
end

UI:setPage(breedingPage)

UI:pullEvents()

