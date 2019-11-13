local Config = require('opus.config')
local UI     = require('opus.ui')

local config = Config.load('secure', {
	enabled = false,
    timeout = 60,
})

local tab = UI.Tab {
	tabTitle = 'Secure',
	description = 'Secure options',
	label1 = UI.Text {
		x = 2, y = 3,
		value = 'Screen Locking',
	},
	checkbox = UI.Checkbox {
		x = 20, y = 3,
		value = config.enabled
	},
	label2 = UI.Text {
		x = 2, y = 4,
		value = 'Lock timeout',
	},
	timeout = UI.TextEntry {
		x = 20, y = 4, width = 6,
		limit = 4,
		transform = 'number',
		value = config.timeout,
		accelerators = {
			enter = 'update',
		},
	},
	button = UI.Button {
		x = 20, y = 6,
		text = 'Update',
		event = 'update',
	},
}

function tab:eventHandler(event)
	if event.type =='checkbox_change' then
		config.enabled = not not event.checked

	elseif event.type == 'update' then
		if self.timeout.value then
			config.timeout = self.timeout.value
			Config.update('secure', config)

			self:emit({ type = 'success_message', message = 'Settings updated' })
			os.queueEvent('config_update', 'secure', config)
		else
			self:emit({ type = 'error_message', message = 'Invalid timeout' })
		end
	end
	return UI.Tab.eventHandler(self, event)
end

return tab
