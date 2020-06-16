local Config = require('opus.config')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local ccemux = _G.ccemux

local sides = { 'bottom', 'top', 'back', 'front', 'right', 'left' }

local tab = UI.Tab {
	title = 'CCEmuX',
	description = 'CCEmuX peripherals',
	form = UI.Form {
		x = 2, ex = -2, y = 2, ey = 5,
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
			x = 19, y = 3,
			formKey = 'drive_id',
			shadowText = 'id',
			width = 5,
			limit = 3,
			transform = 'number',
		},
		add = UI.Button {
			x = -6, y = 3, width = 5,
			text = 'Add', event = 'form_ok',
		},
	},
	grid = UI.Grid {
		x = 2, ex = -2, y = 7, ey = -2,
		columns = {
			{ heading = 'Side', key = 'side', width = 8 },
			{ heading = 'Type', key = 'type' },
			{ heading = 'ID',   key = 'args', width = 4 },
		},
	},
}

function tab:updatePeripherals(config)
	self.grid.values = { }
	for k,v in pairs(config) do
		table.insert(self.grid.values, {
			side = k,
			type = v.type,
			args = v.args and v.args.id,
		})
	end
	self.grid:update()
end

function tab.bootCheck()
	local startupFile = 'packages/ccemux/bin/emustartup.lua'

	local c = Util.readTable('.startup.boot')
	if c then
		for _,v in pairs(c.preload) do
			if v == startupFile then
				return
			end
		end
	end
	table.insert(c.preload, startupFile)
	Util.writeTable('.startup.boot', c)
end

function tab:enable()
	self:bootCheck()
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
		if event.values.type == 'disk_drive' and not event.values.drive_id then
			self:emit({ type = 'error_message', message = 'Invalid drive ID' })
		else
			ccemux.detach(event.values.side)

			local config = Config.load('ccemux')
			config[event.values.side] = {
				type = event.values.type
			}
			if event.values.type == 'disk_drive' then
				config[event.values.side].args = {
					id = event.values.drive_id
				}
				ccemux.attach(event.values.side, event.values.type, { id = event.values.drive_id })
			else
				ccemux.attach(event.values.side, event.values.type)
			end
			Config.update('ccemux', config)
			self:updatePeripherals(config)
			self.grid:draw()

			self:emit({ type = 'success_message', message = 'Attached' })
		end

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
