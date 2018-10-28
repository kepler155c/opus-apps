local UI     = require('ui')

local colors = _G.colors
local device = _G.device

local dispenserView = UI.Window {
	index = 10,
	title = 'Redstone Control',
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 1, y = 2, ex = -1, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Interval', formKey = 'interval',
			help = 'Pulse redstone if items are present',
			limit = 6,
			validate = 'numeric',
		},
		[2] = UI.Chooser {
			formLabel = 'Integrator', formKey = 'integrator',
			nochoice = 'disable',
			help = 'Control via redstone',
		},
		[3] = UI.Chooser {
			width = 10,
			formLabel = 'Side', formKey = 'side',
			choices = {
				{ name = 'up', value = 'up' },
				{ name = 'down', value = 'down' },
				{ name = 'east', value = 'east' },
				{ name = 'north', value = 'north' },
				{ name = 'west', value = 'west' },
				{ name = 'south', value = 'south' },
			},
			help = 'Output side',
		},
	},
}

function dispenserView:isValidFor(machine)
	if machine.mtype == 'machine' then
		local m = device[machine.name]
		return m and m.type == 'minecraft:dispenser'
	end
end

function dispenserView:enable()
	UI.Window.enable(self)
	self:focusFirst()

	self.form[2].choices = { }
	for _,m in pairs(device) do
		if m.type == 'redstone_integrator' then
			table.insert(self.form[2].choices, {
				name = m.name,
				value = m.name,
			})
		end
	end
end

function dispenserView:validate()
	return self.form:save()
end

function dispenserView:setMachine(machine)
	if not machine.redstone then
		machine.redstone = { }
	end
	self.form:setValues(machine.redstone)
end

UI:getPage('machineWizard').wizard:add({ dispenser = dispenserView })
