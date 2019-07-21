local UI     = require('opus.ui')
local Krist  = require('swshop.krist')--??

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
			formLabel = 'Header', formKey = 'header',
			help = 'Text to show in header',
			limit = 64,
			shadowText = "xxxx's shop",
			required = false,
		},
		[3] = UI.Checkbox {
			formLabel = 'Single shop', formKey = 'refundInvalid',
			help = 'Only this shop uses this domain',
			limit = 64,
		},
		[4] = UI.Chooser {
			width = 9,
			formLabel = 'Font Size', formKey = 'textScale',
			nochoice = 'Small',
			choices = {
				{ name = 'Small', value = .5 },
				{ name = 'Large', value = 1  },
			},
			help = 'Adjust text scaling',
		},
		[5] = UI.TextEntry {
			formLabel = 'Password', formKey = 'password',
			shadowText = 'password or private key',
			limit = 256,
			required = true,
			pass = true,
			help = 'Krist wallet password',
		},
		[6] = UI.Checkbox {
			formLabel = 'Is private key', formKey = 'isPrivateKey',
			help = 'Password is in private key format',
			limit = 64,
			ispkey = true,
		},
		[7] = UI.TextEntry {
			inactive = true,
			backgroundColor = colors.cyan,
			textColor = colors.yellow,
			formLabel = 'Using address',
			formKey = 'address',
		},
	},
}

local function makeAddress(text, isPrivateKey)
	local privKey = text
	if not isPrivateKey then
		privKey = Krist.toKristWalletFormat(privKey)
	end
	return Krist.makev2address(privKey)
end

function wizardPage.form:eventHandler(event)
	if (event.type == 'text_change' and event.element.pass) or
		 (event.type == 'checkbox_change' and event.element.ispkey) then
		self[7].value = makeAddress(self[5].value, self[6].value)
		self[7]:draw()
	end
	return UI.Form.eventHandler(self, event)
end

function wizardPage:setNode(node)
	node.address = node.password and makeAddress(node.password, node.isPrivateKey) or ''
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
