local Config = require('opus.config')
local Map    = require('opus.map')
local UI     = require('opus.ui')

local os     = _G.os

local config = Config.load('shop')

local shopTab = UI.Tab {
	tabTitle = 'Store',
	index = 2,
	form = UI.Form {
		x = 2, ex = -2, y = 2, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Name', formKey = 'name',
			help = 'Unique name used when paying for an item',
			transform = 'lowercase',
			required = true,
			width = 12,
			limit = 64,
		},
		[2] = UI.TextEntry {
			width = 6,
			formLabel = 'Price', formKey = 'price',
			help = 'Per item cost',
			required = true,
			transform = 'number',
		},
		[3] = UI.TextEntry {
			limit = 64,
			formLabel = 'Extra Info', formKey = 'info',
			help = 'Additional info to display for item',
		},
		clearButton = UI.Button {
			x = 2, y = -2,
			event = 'clear',
			text = 'Remove',
		},
		updateButton = UI.Button {
			x = -12, y = -2,
			event = 'update',
			text = 'Update',
		},
	},
}

function shopTab:setItem(item)
	self.item = item
	self.form:setValues(config[item.key] or { })
end

function shopTab:eventHandler(event)
	if event.type == 'clear' then
		self.form:setValues({ })
		config[self.item.key] = nil
		Config.update('shop', config)
		os.queueEvent('shop_refresh')
		self.form:draw()

	elseif event.type == 'update' then
		if self.form:save() then
			Map.removeMatches(config, { name = self.form.values.name })
			config[self.item.key] = self.form.values
			Config.update('shop', config)
			os.queueEvent('shop_refresh')
			self:emit({ type = 'success_message', message = 'Updated' })
		end

	else
		return
	end
	return true
end

return { itemTab = shopTab }
