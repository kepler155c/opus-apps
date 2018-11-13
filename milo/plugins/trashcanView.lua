local Milo   = require('milo')
local UI     = require('ui')

local colors = _G.colors
local device = _G.device

--[[ Configuration Screen ]]
local wizardPage = UI.Window {
  title = 'Trashcan',
  index = 2,
  backgroundColor = colors.cyan,
  form = UI.Form {
    x = 1, y = 1, ex = -1, ey = -2,
    manualControls = true,
    [1] = UI.Checkbox {
      formLabel = 'Drop', formKey = 'drop',
      help = 'Drop the items out of this inventory',
    },
    [2] = UI.Chooser {
      width = 9,
      formLabel = 'Drop direction', formKey = 'dropDirection',
      nochoice = 'Down',
      choices = {
        { name = 'Down', value = 'down' },
        { name = 'Up',   value = 'up' },
        { name = 'North', value = 'north' },
        { name = 'South', value = 'south' },
        { name = 'East', value = 'east' },
        { name = 'West', value = 'west' },
      },
      help = 'Drop in a specified direction'
    },
  },
}

function wizardPage:enable()
  UI.Window.enable(self)
  self:focusFirst()
end

function wizardPage:validate()
  return self.form:save()
end

function wizardPage:setNode(node)
  self.form:setValues(node)
end

function wizardPage:isValidType(node)
  local m = device[node.name]
  return m and m.pullItems and {
    name = 'Trashcan',
    value = 'trashcan',
    help = 'An inventory to send unwanted items',
  }
end

function wizardPage:isValidFor(node)
  return node.mtype == 'trashcan'
end

UI:getPage('nodeWizard').wizard:add({ trashcan = wizardPage })

--[[ TASK ]]--
local task = {
  name = 'trashcan',
  priority = 90,
}

local function filter(a)
  return a.drop
end

function task:cycle(context)
  for node in context.storage:filterActive('trashcan', filter) do
    for k in pairs(node.adapter.list()) do
      local direction = node.dropDirection or 'down'
      node.adapter.drop(k, 64, direction)
    end
  end
end

Milo:registerTask(task)
