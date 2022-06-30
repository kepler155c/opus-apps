local UI         = require('opus.ui')
local Util       = require('opus.util')
local Peripheral = require('opus.peripheral')

local defaultStoragePath = "/usr/config/storage"

local page = UI.Page {
	notification = UI.Notification {},

	infoText = UI.TextArea {
		x = 2, y = 2,
		height = 2,
		textColor = colors.yellow,
		value = "Select storage types to merge into your Milo storage config.",
	},

	typeGrid = UI.CheckboxGrid {
		x = 2, y = 4,
		ex = -2, ey = -4,
		sortColumn = "amount",
		inverseSort = true,
		columns = {
			{heading = 'Type', key = 'type'},
			{heading = 'Amount', key = 'amount', align = 'right', width = 6},
		},
	},

	rescanButton = UI.Button {
		x = 2, y = -2,
		text = 'Rescan',
		event = 'rescan',
	},

	doneButton = UI.Button {
		x = -7, y = -2,
		text = 'Save',
		event = 'save',
	},

	confirm = UI.Question {
		x = -38, y = -2,
		label = 'Overwrite Milo settings?',
	},

	fileSelect = UI.FileSelect {
		modal = true,
		enable = function() end,
		transitionHint = 'expandUp',
		show = function(self)
			UI.FileSelect.enable(self)
			self:focusFirst()
			self:draw()
		end,
		disable = function(self)
			UI.FileSelect.disable(self)
			self.parent:focusFirst()
			self.parent:capture(self.parent)
		end,
		eventHandler = function(self, event)
			if event.type == 'select_cancel' then
				self:disable()
			elseif event.type == 'select_file' then
				self:disable()
			end
			return UI.FileSelect.eventHandler(self, event)
		end,
	},
}

function page:scan()
	self.storages = Util.filter(Peripheral.getList(), function(dev)
		return dev.pushItems
	end)

	local types = {}
	Util.each(self.storages, function(dev, name)
		if not types[dev.type] then types[dev.type] = {amount = 0, type = dev.type} end
		types[dev.type].amount = types[dev.type].amount + 1
	end)

	self.typeGrid:setValues(types)
	self:draw()
	self:sync()
end

function page:saveConfig(path)
	local config = Util.readTable(path) or {}
	Util.each(self.storages, function(dev, name)
		if self.typeGrid.values[dev.type] and self.typeGrid.values[dev.type].checked and (not config[name] or config[name].mtype == 'ignore') then
			config[name] = {
				name = name,
				category = 'storage',
				mtype = 'storage',
			}
		end
	end)
	Util.writeTable(path, config)

	self.notification:success("Config saved to "..path)
end

function page:enable()
	UI.Page.enable(self)
	self:scan()
end

function page.typeGrid:getRowTextColor(row, selected)
	return row.checked and colors.yellow or UI.Grid.getRowTextColor(self, row, selected)
end

function page:eventHandler(event)
	if event.type == "rescan" then
		self:scan()

	elseif event.type == "save" then
		self.confirm:show()

	elseif event.type == "question_yes" then
		self:saveConfig(defaultStoragePath)
		self.confirm:hide()

	elseif event.type == "question_no" then
		self.confirm:hide()
		self.fileSelect:show()

	elseif event.type == "select_file" then
		self:saveConfig(event.file)

	else return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:setPage(page)
UI:start()
