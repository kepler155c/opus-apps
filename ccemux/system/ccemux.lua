local Config = require('config')
local UI     = require('ui')

local ccemux = _G.ccemux

local sides = { 'bottom', 'top', 'back', 'front', 'right', 'left' }

local tab = UI.Tab {
	tabTitle = 'CCEmuX',
	description = 'CCEmuX peripherals',
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = 4,
		values = {
			side = 'bottom',
			type = 'wireless_modem',
		},
		manualControls = true,
		side = UI.Chooser {
			formLabel = 'Side', formKey = 'side',
			width = 10,
		},
		ptype = UI.Chooser {
			formLabel = 'Type', formKey = 'type',
			width = 10,
			choices = {
				{ name = 'Modem', value = 'wireless_modem' },
				{ name = 'Drive', value = 'disk_drive'     },
			},
		},
		drive_id = UI.TextEntry {
			x = 20, y = 3,
			formKey = 'drive_id',
			shadowText = 'id',
			width = 5,
			limit = 3,
		},
		add = UI.Button {
			x = 28, y = 3,
			text = 'Add', event = 'form_ok',
			help = 'Add items to turtle to add to filter',
		},
	},
	grid = UI.Grid {
		x = 3, ex = -3, y = 6, ey = -2,
		columns = {
			{ heading = 'Side', key = 'side', width = 8 },
			{ heading = 'Type', key = 'type' },
		},
	},
}

function tab:updatePeripherals(config)
	self.grid.values = { }
	for k,v in pairs(config) do
		table.insert(self.grid.values, {
			side = k,
			type = v.type,
			args = v.args,
		})
	end
	self.grid:update()
end

function tab:enable()
	local config = Config.load('ccemux')

	local choices = { }
	for _,k in pairs(sides) do
		table.insert(choices, { name = k, value = k })
	end
	self.form.side.choices = choices

	self:updatePeripherals(config)
	UI.Tab.enable(self)

	self.form.drive_id.enabled = false
end

function tab:eventHandler(event)
	if event.type == 'form_complete' then
		ccemux.detach(event.values.side)
		ccemux.attach(event.values.side, event.values.type)

		local config = Config.load('ccemux')
		config[event.values.side] = {
			type = event.values.type
		}
		if event.values.type == 'disk_drive' and tonumber(event.values.drive_id) then
			config[event.values.side].args = {
				id = tonumber(event.values.drive_id)
			}
		end
		Config.update('ccemux', config)
		self:updatePeripherals(config)
		self.grid:draw()

		self:emit({ type = 'success_message', message = 'Attached' })

	elseif event.type == 'choice_change' then
		if event.element == self.form.ptype then
			self.form.drive_id.enabled = event.value == 'disk_drive'
			self.form:draw()
		end

	elseif event.type == 'grid_select' then
		local config = Config.load('ccemux')
		config[event.selected.side] = nil
		Config.update('ccemux', config)
		self:updatePeripherals(config)
		self.grid:draw()

		self:emit({ type = 'success_message', message = 'Detached' })

		return true
	end
end

return tab
