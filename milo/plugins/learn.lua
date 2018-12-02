local Milo   = require('milo')
local UI     = require('ui')

local context = Milo:getContext()
local turtle = _G.turtle

local learnPage = UI.Dialog {
  height = 9, width = UI.term.width - 6,
  title = 'Learn Recipe',
  grid = UI.ScrollingGrid {
    x = 2, ex = -2, y = 3, height = 4,
    disableHeader = true,
    columns = {
      { heading = 'Name', key = 'name'},
    },
    sortColumn = 'name',
  },
  cancel = UI.Button {
    x = 3, y = -2,
    text = 'Cancel', event = 'cancel'
  },
  accept = UI.Button {
    ex = -3, y = -2,
    width = 8,
    text = 'Ok', event = 'accept',
  },
}

function learnPage:enable()
  local t = { }
  for k in pairs(context.learnTypes) do
    table.insert(t, {
      name = k,
      value = k,
    })
  end
  self.grid:setValues(t)
  self.grid:setSelected('name', Milo:getState('learnType') or '')

  Milo:pauseCrafting({ key = 'gridInUse', msg = 'Crafting paused' })

  self:focusFirst()
  UI.Dialog.enable(self)
end

function learnPage:disable()
  UI.Dialog.disable(self)
end

function learnPage:eventHandler(event)
  if event.type == 'cancel' then
    Milo:resumeCrafting({ key = 'gridInUse' })
    turtle.emptyInventory()
    UI:setPreviousPage()

  elseif event.type == 'accept' or event.type == 'grid_select' then
    local choice = self.grid:getSelected().value

    Milo:setState('learnType', choice)
    UI:setPage(context.learnTypes[choice])
  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

UI:addPage('learn', learnPage)
