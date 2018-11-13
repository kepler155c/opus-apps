local itemDB = require('itemDB')
local UI     = require('ui')

local colors = _G.colors
local device = _G.device

local storageView = UI.Window {
	title = 'Storage Options',
	index = 2,
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 1, y = 1, ex = -1, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Priority', formKey = 'priority',
			help = 'Larger values get precedence',
			limit = 4,
			validate = 'numeric',
			shadowText = 'Numeric priority',
		},
		[2] = UI.Checkbox {
			formLabel = 'Locked', formKey = 'lockWith',
			help = 'Locks chest to current item types',
		},
		[3] = UI.Text {
			x = 16, ex = -2, y = 3,
			value = '',
		},
		[4] = UI.Checkbox {
			formLabel = 'Void', formKey = 'void',
			help = 'Void items if locked chest is full',
		},
		[5] = UI.TextEntry {
			formLabel = 'Refresh', formKey = 'refreshInterval',
			shadowText = 'seconds between refresh',
			limit = 4,
			validate = 'numeric',
			help = 'Refresh periodically',
		},
		[6] = UI.TextArea {
			x = 12, ex = -2, y = 6,
			textColor = colors.yellow,
			value = 'Only specify if you are manually taking items out of this inventory. Value should be > 10',
		},
--[[
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
]]--
	},
}

function storageView:showLockTypes()
	local types = { }
	if self.node.lock then
		if type(self.node.lock) == 'string' then
			self.form[3].value = self.node.lock
			return
		end
		for name in pairs(self.node.lock) do
			table.insert(types, itemDB:getName(name))
		end
	end
	self.form[3].value = table.concat(types, ', ')
end

function storageView:enable()
	UI.Window.enable(self)
	self:focusFirst()
	self:showLockTypes()
end

function storageView:validate()
	return self.form:save()
end

function storageView:isValidType(node)
	local m = device[node.name]
	return m and m.pullItems and {
		name = 'Storage',
		value = 'storage',
		help = 'Use for item storage',
	}
end

function storageView:isValidFor(node)
	return node.mtype == 'storage'
end

function storageView:setNode(node)
	self.node = node
	self.form:setValues(node)
	self:showLockTypes()
end

function storageView:eventHandler(event)
	if event.type == 'checkbox_change' and event.element.formKey == 'lockWith' then
		if event.checked then
			if device[self.node.name] and device[self.node.name].list then
				local lock = { }
				for _, slot in pairs(device[self.node.name].list()) do
					lock[itemDB:makeKey(slot)] = true
				end
				if not next(lock) then
					self:emit({
						type = 'general_error',
						field = event.element,
						message = 'The chest must contain the item(s) to lock' })
					self.form[3].value = false
				else
					self.node.lock = lock
				end
			end
		else
			self.node.lock = nil
			self.form[3].value = ''
		end
		self:showLockTypes()
		self.form[3]:draw()
	end
end

UI:getPage('nodeWizard').wizard:add({ storage = storageView })
