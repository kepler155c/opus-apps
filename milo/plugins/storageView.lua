local UI = require('ui')

local colors = _G.colors

local storageView = UI.Window {
	mtype = 'storage',
	title = 'Storage Options',
	index = 2,
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 1, y = 2, ex = -1, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Priority', formKey = 'priority',
			help = 'Larger values get precedence',
			limit = 4,
			validate = 'numeric', pruneEmpty = true,
		},
		[2] = UI.TextEntry {
			formLabel = 'Lock to', formKey = 'lockWith',
			help = 'Locks chest to a single item type',
			width = 18, limit = 64, pruneEmpty = true,
		},
		[3] = UI.Button {
			x = -9, ey = -4,
			text = 'Detect', help = 'Determine what is currently present',
		},
	},
}

function storageView:enable()
	UI.Window.enable(self)
	self:focusFirst()
end

function storageView:validate()
	return self.form:save()
end

function storageView:setMachine(machine)
	self.form:setValues(machine)
end

UI:getPage('machineWizard').wizard:add({ storage = storageView })
