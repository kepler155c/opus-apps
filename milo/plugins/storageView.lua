local itemDB = require('core.itemDB')
local UI     = require('opus.ui')

local colors = _G.colors
local device = _G.device

local storageView = UI.WizardPage {
	title = 'Storage Options - General',
	index = 2,
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = -2,
		manualControls = true,
		[1] = UI.TextEntry {
			formLabel = 'Priority', formKey = 'priority',
			help = 'Larger values get precedence',
			limit = 4,
			validate = 'numeric',
			shadowText = 'Numeric priority',
		},
		[2] = UI.TextEntry {
			formLabel = 'Refresh', formKey = 'refreshInterval',
			shadowText = 'seconds between refresh',
			limit = 4,
			validate = 'numeric',
			help = 'Refresh periodically',
		},
		[3] = UI.TextArea {
			x = 12, ex = -2, y = 4,
			textColor = colors.yellow,
			marginRight = 0,
			value = 'Only specify if you are manually taking items out of this inventory. Value should be > 10',
		},
	},
}

function storageView:validate()
	return self.form:save()
end

function storageView:isValidType(node)
	local m = device[node.name]
	return m and m.pullItems and {
		name = 'Storage',
		value = 'storage',
		category = 'storage',
		help = 'Use for item storage',
	}
end

function storageView:isValidFor(node)
	return node.mtype == 'storage'
end

function storageView:setNode(node)
	self.form:setValues(node)
end

UI:getPage('nodeWizard').wizard:add({ storageGeneral = storageView })

--[[ Locking Page ]]--
local lockView = UI.WizardPage {
	title = 'Storage Options - Locking',
	index = 3,
	backgroundColor = colors.cyan,
	form = UI.Form {
		x = 2, ex = -2, y = 1, ey = 3,
		manualControls = true,
		[1] = UI.Checkbox {
			formLabel = 'Locked', formKey = 'lockWith',
			help = 'Locks chest to current item types',
		},
		[2] = UI.Checkbox {
			formLabel = 'Void', formKey = 'void',
			help = 'Void items if locked chest is full',
		},
	},
	grid = UI.ScrollingGrid {
		x = 2, ex = -2, y = 5, ey = -2,
		columns = {
			{ heading = 'Name', key = 'displayName' },
		},
		sortColumn = 'displayName',
		disableHeader = true,
	},
}

function lockView:showLockTypes()
	self.grid.values = { }
	if self.node.lock then
		for key in pairs(self.node.lock) do
			table.insert(self.grid.values, {
				displayName = itemDB:getName(key),
				key = key,
			})
		end
	end
	self.grid:update()
	self.grid:draw()
end

function lockView:validate()
	return self.form:save()
end

function lockView:isValidType(node)
	local m = device[node.name]
	return m and m.pullItems and {
		name = 'Storage',
		value = 'storage',
		category = 'storage',
		help = 'Use for item storage',
	}
end

function lockView:isValidFor(node)
	return node.mtype == 'storage'
end

function lockView:setNode(node)
	self.node = node
	self.form:setValues(node)
	self:showLockTypes()
end

function lockView:eventHandler(event)
	if event.type == 'checkbox_change' and event.element.formKey == 'lockWith' then
		if event.checked then
			if device[self.node.name] and device[self.node.name].list then
				local list = device[self.node.name].list()
				if not next(list) then
					self:emit({
						type = 'general_error',
						field = event.element,
						message = 'The chest must contain the item(s) to lock' })
				else
					self.node.lock = { }
					for _, slot in pairs(list) do
						self.node.lock[itemDB:makeKey(slot)] = true
					end
				end
			end
		else
			self.node.lock = nil
		end
		self:showLockTypes()
	end
end

UI:getPage('nodeWizard').wizard:add({ storageLock = lockView })
