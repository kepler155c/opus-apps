local UI     = require('opus.ui')
local Krist  = require('swshop.krist')

local colors = _G.colors
local device = _G.device
local os     = _G.os

local defaultKristNode = "https://krist.dev"

--[[ Configuration Page ]]--
local wizardPage = UI.WizardPage {
	title = 'Store Front',
	index = 2,
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Header', formKey = 'header',
			help = 'Text to show in header',
			limit = 64,
			shadowText = "xxxx's shop",
			required = false,
		},
		[2] = UI.Checkbox {
			formLabel = 'Single shop', formKey = 'refundInvalid',
			help = 'Only this shop uses this domain',
		},
		[3] = UI.Checkbox {
			formLabel = 'Show out of stock', formKey = 'showOutOfStock',
			help = 'Show out of stock items in red',
		},
		[4] = UI.Chooser {
			formLabel = 'RS Signal', formKey = 'rsSide', formIndex = 6,
			width = 10,
			choices = {
				{name = 'Bottom', value = 'bottom'},
				{name = 'Top', value = 'top'},
				{name = 'Back', value = 'back'},
				{name = 'Front', value = 'front'},
				{name = 'Right', value = 'right'},
				{name = 'Left', value = 'left'},
			},
			required = true,
		},
		[5] = UI.Chooser {
			width = 9,
			formIndex = 7,
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
local kristPage = UI.WizardPage {
	title = 'Krist Settings',
	index = 3,
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = -2,
		manualControls = true,

		nodeEntry = UI.TextEntry {
			formIndex = 1,
			formLabel = 'Sync Node', formKey = 'syncNode',
			shadowText = 'http(s)://domain:port',
			help = 'Sync node the shop will use',
			limit = 256,
			required = true,
		},

		domainEntry = UI.TextEntry {
			formIndex = 3,
			formLabel = 'Domain', formKey = 'domain',
			help = 'Krist wallet domain (minus .kst)',
			limit = 64,
			shadowText = 'example',
			required = true,
		},

		passEntry = UI.TextEntry {
			formIndex = 4,
			formLabel = 'Password', formKey = 'password',
			shadowText = 'Password',
			help = 'Krist wallet password',
			limit = 256,
			required = true,
			pass = true,
		},

		pkeyCheck = UI.Checkbox {
			formIndex = 5,
			formLabel = 'Private key', formKey = 'isPrivateKey',
			help = 'Password is in private key format',
			ispkey = true,
		},

		preview = UI.TextEntry {
			formIndex = 7,
			formLabel = 'Address', formKey = 'address',
			backgroundColor = 'primary',
			textColor = colors.yellow,
			inactive = true,
		},
	},
}

local function makeAddress(text, isPrivateKey)
	local privKey = text or ''
	if not isPrivateKey then
		privKey = Krist.toKristWalletFormat(privKey)
	end
	return Krist.makev2address(privKey)
end

function kristPage.form:eventHandler(event)
	if (event.type == 'text_change' and event.element.pass) or
		 (event.type == 'checkbox_change' and event.element.ispkey) then
		self.passEntry.shadowText = self.pkeyCheck.value and 'Private key' or 'Password'
		self.preview.value = makeAddress(self.passEntry.value, self.pkeyCheck.value)
		self:draw()
	end
	return UI.Form.eventHandler(self, event)
end

function kristPage:setNode(node)
	node.address = node.password and makeAddress(node.password, node.isPrivateKey) or ''
	node.syncNode = node.syncNode or defaultKristNode
	self.form:setValues(node)
end

local function addressHasName(node, address, domain)
	local res, err = http.get(node .. "/addresses/" .. address .. "/names")
	if res then
		local data = textutils.unserializeJSON(res.readAll())
		if data.ok then
			for _, name in pairs(data.names) do
				if name.name == domain then
					return true
				end
			end
			return false, "This address doesn't own this name"
		end
		return false, data.error
	end
	return false, "Error while checking names"
end

function kristPage:validate()
	local ok, err = http.checkURL(self.form.nodeEntry.value or '')

	if ok then
		ok, err = addressHasName(self.form.nodeEntry.value, self.form.preview.value, self.form.domainEntry.value)
		if ok then
			return self.form:save()
		end
	end
	self:emit({ type = 'general_error', message = err })
end

function kristPage:isValidFor(node)
	return node.mtype == 'shop'
end

UI:getPage('nodeWizard').wizard:add({ storeFronta = wizardPage, storeFrontb = kristPage })
