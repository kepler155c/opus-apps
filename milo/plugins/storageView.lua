local itemDB = require('itemDB')
local UI     = require('ui')

local colors = _G.colors
local device = _G.device

local storageView = UI.Window {
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
		[2] = UI.Checkbox {
			formLabel = 'Locked', formKey = 'lockWith',
			help = 'Locks chest to a single item type',
			pruneEmpty = true,
		},
		[3] = UI.Text {
			x = 16, ex = -2, y = 3,
			value = '',
		},
		[4] = UI.Checkbox {
			formLabel = 'Void', formKey = 'voidExcess',
			help = 'Void excess if locked - TODO',
			pruneEmpty = true,
		},
		[5] = UI.Checkbox {
			formLabel = 'Partition', formKey = 'partition',
			help = 'TODO',
			pruneEmpty = true,
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

function storageView:isValidFor(machine)
	return machine.mtype == 'storage'
end

function storageView:setMachine(machine)
	self.machine = machine
	self.form:setValues(machine)
	self.form[3].value = machine.lock and itemDB:getName(machine.lock) or ''
end

function storageView:eventHandler(event)
	if event.type == 'checkbox_change' and event.element.formKey == 'lockWith' then
		if event.checked then
			if device[self.machine.name] and device[self.machine.name].list then
				local _, slot = next(device[self.machine.name].list())
				if slot then
					self.machine.lock = itemDB:makeKey(slot)
					self.form[3].value = itemDB:getName(slot)
				else
					self:emit({
						type = 'general_error',
						field = event.element,
						message = 'The chest must contain the item to lock' })
					self.form[3].value = false
					self.form[3]:draw()
				end
			end
		else
			self.machine.lock = nil
			self.form[3].value = ''
		end
		self.form[3]:draw()
	end
end

UI:getPage('machineWizard').wizard:add({ storage = storageView })
