local Ansi   = require('ansi')
local Milo   = require('milo')
local Sync   = require('sync')
local UI     = require('ui')

local colors = _G.colors
local device = _G.device
local turtle = _G.turtle

--[[ Configuration Screen ]]--
local wizardPage = UI.Window {
  title = 'Manipulator',
  index = 2,
  backgroundColor = colors.cyan,
  form = UI.Form {
    x = 2, ex = -2, y = 3, ey = -2,
    manualControls = true,
    [1] = UI.Checkbox {
      formLabel = 'Import', formKey = 'importEnder',
      help = 'Locks chest to a single item type',
      pruneEmpty = true,
    },
    [2] = UI.TextArea {
      x = 13, ex = -2, y = 2,
      value = 'Automatically import the user\'s ender chest contents',
    },
  },
  userInfo = UI.TextArea {
    x = 3, ex = -2, y = 2, height = 2,
  },
}

function wizardPage:isValidType(node)
  local m = device[node.name]
  return m and
         m.type == 'manipulator' and
         m.getEnder and
         {
           name = 'Manipulator',
           value = 'manipulator',
           category = 'custom',
           help = 'Manipulator w/bound introspection mod'
         }
end

function wizardPage:isValidFor(node)
  return node.mtype == 'manipulator'
end

function wizardPage:setNode(node)
  self.form:setValues(node)
  self.userInfo.value = string.format('%sBound to:  %s%s',
    Ansi.black, Ansi.yellow, node.adapter.getName())
end

function wizardPage:validate()
  return self.form:save()
end

UI:getPage('nodeWizard').wizard:add({ manipulator = wizardPage })

--[[ Task ]]--
local task = {
  name = 'manipulator',
  priority = 15,
}

function task:cycle(context)
  local function filter(v)
    return v.adapter.getEnder and v.importEnder
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
