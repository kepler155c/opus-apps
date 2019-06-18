local UI     = require('ui')

local colors = _G.colors
local device = _G.device
local os     = _G.os

--[[ Configuration Page ]]--
local wizardPage = UI.WizardPage {
	title = 'Store Front',
	index = 2,
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Domain', formKey = 'domain',
			help = 'Krist wallet domain (minus .kst)',
			limit = 64,
			shadowText = 'example',
			required = true,
		},
		[2] = UI.TextEntry {
			formLabel = 'Password', formKey = 'password',
			shadowText = 'password',
			limit = 256,
			required = true,
			help = 'Krist wallet password',
		},
		[3] = UI.TextEntry {
			formLabel = 'Header', formKey = 'header',
			help = 'Text to show in header',
			limit = 64,
			shadowText = "xxxx's shop",
			required = false,
		},
		[4] = UI.Checkbox {
			formLabel = 'Is private key', formKey = 'isPrivateKey',
			help = 'Password is in private key format',
			limit = 64,
		},
		[5] = UI.Chooser {
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
	os.queueEvent('shop_restart', node)
end

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'monitor' and {
		name = 'Store Front',
		value = 'shop',
		category = 'display',
		help = 'Add a store front display'
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'shop'
end

UI:getPage('nodeWizard').wizard:add({ storeFront = wizardPage })
