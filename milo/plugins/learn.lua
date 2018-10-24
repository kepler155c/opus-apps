local Milo   = require('milo')
local UI     = require('ui')

local context = Milo:getContext()

local learnPage = UI.Dialog {
  height = 6, width = UI.term.width - 6,
  title = 'Learn Recipe',
  chooser = UI.Chooser {
    x = 8, y = 3,
    width = 20,
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
  self.chooser.choices = { }

  for k in pairs(context.learnTypes) do
    table.insert(self.chooser.choices, {
      name = k,
      value = k,
    })
  end
  self.chooser.value =
    Milo:getState('learnType') or
    self.chooser.choices[1].value

  self:focusFirst()
  UI.Dialog.enable(self)
end

function learnPage:disable()
  UI.Dialog.disable(self)
end

function learnPage:eventHandler(event)
  if event.type == 'cancel' then
    UI:setPreviousPage()

  elseif event.type == 'accept' then
    local choice = self.chooser.value

    Milo:setState('learnType', choice)
    UI:setPage(context.learnTypes[choice])

  else
    return UI.Dialog.eventHandler(self, event)
  end
  return true
end

UI:addPage('learn', learnPage)
