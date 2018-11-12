local Ansi   = require('ansi')
local Milo   = require('milo')
local Sync   = require('sync')
local UI     = require('ui')

local colors = _G.colors
local device = _G.device
local turtle = _G.turtle

--[[ Configuration Screen ]]
local template =
[[%sBound Manipulator%s

Automatically import items into storage from your ender chest.
]]

local wizardPage = UI.Window {
  title = 'Manipulator',
  index = 2,
  backgroundColor = colors.cyan,
  [1] = UI.TextArea {
    x = 2, ex = -2, y = 2, ey = -2,
    value = string.format(template, Ansi.yellow, Ansi.reset),
  },
}

function wizardPage:isValidType(node)
  local m = device[node.name]
  return m and
         m.type == 'manipulator' and
         m.getEnder and
         { name = 'Manipulator', value = 'manipulator' }
end

function wizardPage:isValidFor(node)
  return node.mtype == 'manipulator'
end

UI:getPage('nodeWizard').wizard:add({ manipulator = wizardPage })

local task = {
  name = 'manipulator',
  priority = 15,
}

function task:cycle(context)
  local function filter(v)
    return v.adapter.getEnder
  end

  for manipulator in context.storage:filterActive('manipulator', filter) do
    for slot, item in pairs(manipulator.adapter.getEnder().list()) do
      Sync.sync(turtle, function()
        manipulator.adapter.getEnder().pushItems(
          context.localName,
          slot,
          item.count)
        Milo:clearGrid()
      end)
    end
  end
end

Milo:registerTask(task)
