local Ansi       = require('ansi')
local UI         = require('ui')

local colors     = _G.colors
local device     = _G.device

--[[ Configuration Screen ]]
local template =
[[%sUse this inventory as a trashcan%s

If the number of items exceed the maximum value will be sent to this inventory.

Any items that cannot fit into a locked chest will automatically be sent to this inventory.
]]

local trashcanWizardPage = UI.Window {
  title = 'Trashcan',
  index = 2,
  backgroundColor = colors.cyan,
  [1] = UI.TextArea {
    x = 2, ex = -2, y = 2, ey = -2,
    value = string.format(template, Ansi.yellow, Ansi.reset),
  },
}

function trashcanWizardPage:isValidType(node)
  local m = device[node.name]
  return m and m.pullItems and {
    name = 'Trashcan',
    value = 'trashcan',
    help = 'An inventory to send unwanted items',
  }
end

function trashcanWizardPage:isValidFor(node)
  return node.mtype == 'trashcan'
end

UI:getPage('nodeWizard').wizard:add({ trashcan = trashcanWizardPage })
