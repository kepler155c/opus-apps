local UI     = require('opus.ui')
local Krist  = require('swshop.krist')

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
			formIndex = 5,
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

-- [[Password View]] --
local passwordPage = UI.WizardPage {
	title = 'Krist Settings',
	index = 3,
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = -2,
		manualControls = true,
		passEntry = UI.TextEntry {
			formIndex = 1,
			formLabel = 'Password', formKey = 'password',
			shadowText = 'Password',
			help = 'Krist wallet password',
			limit = 256,
			required = true,
			pass = true,
		},
		pkeyCheck = UI.Checkbox {
			formIndex = 2,
			formLabel = 'Is private key', formKey = 'isPrivateKey',
			help = 'Password is in private key format',
			ispkey = true,
		},
		preview = UI.TextEntry {
			formIndex = 4,
			formLabel = 'Using address', formKey = 'address',
			backgroundColor = colors.cyan,
			textColor = colors.yellow,
			inactive = true,
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

function passwordPage.form:eventHandler(event)
	if (event.type == 'text_change' and event.element.pass) or
		 (event.type == 'checkbox_change' and event.element.ispkey) then
  self.passEntry.shadowText = self.pkeyCheck.value and 'Private key' or 'Password'
		self.preview.value = makeAddress(self.passEntry.value, self.pkeyCheck.value)
		self:draw()
	end
	return UI.Form.eventHandler(self, event)
end

function passwordPage:setNode(node)
	node.address = node.password and makeAddress(node.password, node.isPrivateKey) or ''
	self.form:setValues(node)
end

function passwordPage:validate()
	return self.form:save()
end

function passwordPage:isValidFor(node)
	return node.mtype == 'shop'
end

UI:getPage('nodeWizard').wizard:add({ storeFronta = wizardPage, storeFrontb = passwordPage })
