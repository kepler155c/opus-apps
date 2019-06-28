local Config = require('opus.config')
local UI     = require('opus.ui')

local colors = _G.colors
local fs     = _G.fs
local turtle = _G.turtle

if turtle then
	local config = Config.load('gps')

	local gpsTab = UI.Tab {
		tabTitle = 'Home',
		description = 'Turtle home location',
		labelText = UI.Text {
			x = 3, ex = -3, y = 2,
			textColor = colors.yellow,
			value = 'On restart, return to this location'
		},
		grid = UI.Grid {
			x = 3, ex = -3, y = 4,
			height = 2,
			values = { config.home or { } },
			inactive = true,
			columns = {
				{ heading = 'x', key = 'x' },
				{ heading = 'y', key = 'y' },
				{ heading = 'z', key = 'z' },
			},
		},
		button1 = UI.Button {
			x = 3, y = 7,
			text = 'Set home',
			event = 'gps_set',
		},
		button2 = UI.Button {
			ex = -3, y = 7, width = 7,
			text = 'Clear',
			event = 'gps_clear',
		},
		breakingText = UI.Text {
			x = 3, y = 9,
			value = 'Can break blocks',
		},
		breaking = UI.Checkbox {
			x = 20, y = 9,
			value = config.destructive,
		},
	}

	function gpsTab:eventHandler(event)
		if event.type == 'gps_set' then
			self:emit({ type = 'info_message', message = 'Determining location' })
			self:sync()
			local pt = turtle.enableGPS()
			if pt then
				config.home = pt
				Config.update('gps', config)
				self.grid:setValues({ config.home })
				self.grid:draw()
				self:emit({ type = 'success_message', message = 'Location set' })
			else
				self:emit({ type = 'error_message', message = 'Unable to determine location' })
			end
			return true

		elseif event.type == 'checkbox_change' then
			config.destructive = event.checked
			Config.update('gps', config)

		elseif event.type == 'gps_clear' then
			fs.delete('usr/config/gps')
			self.grid:setValues({ })
			self.breaking:reset()
			self:draw()
			return true
		end
	end

	return gpsTab
end
