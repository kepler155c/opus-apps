local UI         = require('ui')

local colors     = _G.colors
local device     = _G.device

--[[ Configuration Page ]]--
local wizardPage = UI.Window {
  title = 'Store Front',
  index = 2,
  backgroundColor = colors.cyan,
  form = UI.Form {
    x = 2, ex = -2, y = 2, ey = -4,
    manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Domain', formKey = 'domain',
			help = 'Krist wallet address',
			limit = 64,
      shadowText = 'example.kst',
      required = true,
		},
		[2] = UI.TextEntry {
			formLabel = 'Password', formKey = 'password',
			shadowText = 'password',
			limit = 64,
      required = true,
			help = 'Krist wallet password',
		},
    [3] = UI.Chooser {
      width = 9,
      formLabel = 'Font Size', formKey = 'textScale',
      nochoice = 'Small',
      choices = {
        { name = 'Small', value = .5 },
        { name = 'Large', value = 1  },
      },
      help = 'Adjust text scaling',
    },
  },
}

function wizardPage:setNode(node)
  self.form:setValues(node)
end

function wizardPage:validate()
  return self.form:save()
end

function wizardPage:saveNode(node)
-- queue event ??
end

function wizardPage:isValidType(node)
  local m = device[node.name]
  return m and m.type == 'monitor' and {
    name = 'Store Front',
    value = 'store',
    category = 'display',
    help = 'Add a store front display'
  }
end

function wizardPage:isValidFor(node)
  return node.mtype == 'store'
end

UI:getPage('nodeWizard').wizard:add({ storeFront = wizardPage })
