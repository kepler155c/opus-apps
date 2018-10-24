local Config = require('config')
local Event  = require('event')
local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device

local context = Milo:getContext()

local machinesPage = UI.Page {
	titleBar = UI.TitleBar {
		previousPage = true,
		title = 'Machines',
	},
	grid = UI.ScrollingGrid {
		y = 2, ey = -2,
		values = context.config.remoteDefaults,
		columns = {
			{ heading = 'Name',     key = 'displayName' },
			{ heading = 'Priority', key = 'priority', width = 5  },
			{ heading = 'Type',     key = 'mtype',    width = 5  },
		},
		sortColumn = 'displayName',
	},
	statusBar = UI.StatusBar {
		values = 'Select Machine',
	},
}

function machinesPage:getList()
	-- TODO: remove dedupe naming in perf code ?
	for _, v in pairs(device) do
		if v.pullItems then
			if not context.config.remoteDefaults[v.name] then
				context.config.remoteDefaults[v.name] = {
					name  = v.name,
					mtype = 'ignore',
				}
			end
		end
	end
end

function machinesPage:enable()
	self:getList()
	self.grid:update()
	UI.Page.enable(self)
	self.handler = Event.on({ 'device_attach', 'device_detach'}, function()
		self:getList()
		self.grid:update()
		self.grid:draw()
		self.grid:sync()
	end)
end

function machinesPage:disable()
	UI.Page.disable(self)
	Event.off(self.handler)
end

function machinesPage.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = row.displayName or row.name
	return row
end

function machinesPage.grid:getRowTextColor(row, selected)
	if not device[row.name] then
		return colors.red
	end
	if row.mtype == 'ignore' then
		return colors.lightGray
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function machinesPage:eventHandler(event)
	if event.type == 'grid_select' then
		UI:setPage('machineWizard', event.selected)
	else
		UI.Page.eventHandler(self, event)
	end
	return true
end

local machineWizard = UI.Page {
	titleBar = UI.TitleBar { title = 'Configure' },
	wizard = UI.Wizard {
		y = 2, ey = -2,
		pages = {
			general = UI.Window {
				index = 1,
				backgroundColor = colors.cyan,
				form = UI.Form {
					x = 1, y = 1, ex = -1, ey = 3,
					manualControls = true,
					[1] = UI.TextEntry {
						formLabel = 'Name', formKey = 'displayName',
						help = 'Set a friendly name',
						limit = 64, pruneEmpty = true,
					},
					[2] = UI.Chooser {
						width = 15,
						formLabel = 'Type', formKey = 'mtype',
						nochoice = 'Storage',
						choices = {
							{ name = 'Storage',     value = 'storage'  },
							{ name = 'Trashcan',    value = 'trashcan' },
							{ name = 'Input chest', value = 'input'    },
							{ name = 'Ignore',      value = 'ignore'   },
							{ name = 'Machine',     value = 'machine'  },
						},
						help = 'Select type',
					},
				},
				grid = UI.ScrollingGrid {
					y = 5, ey = -2, x = 2, ex = -2,
					columns = {
						{ heading = 'Slot', key = 'slot',        width = 4 },
						{ heading = 'Name', key = 'displayName',           },
						{ heading = 'Qty',  key = 'count'      , width = 3 },
					},
					sortColumn = 'slot',
					help = 'Contents of inventory',
				},
			},
			confirmation = UI.Window {
				title = 'Confirm changes',
				index = 2,
				notice = UI.TextArea {
					x = 2, ex = -2, y = 2, ey = -2,
					value =
[[Press accept to save the changes.

The settings will take effect immediately!]],
				},
			},
		},
	},
	statusBar = UI.StatusBar {
		backgroundColor = colors.cyan,
	},
	notification = UI.Notification { },
}

function machineWizard.wizard.pages.general:enable()
	UI.Window.enable(self)
	self:focusFirst()
end

function machineWizard.wizard.pages.general:setMachine(machine)
	local inventory

	if device[machine.name] and device[machine.name].list then
		inventory = device[machine.name].list()
		for k,v in pairs(inventory) do
			v.slot = k
		end
	end

	self.grid:setValues(inventory or { })
end

function machineWizard.wizard.pages.general.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = itemDB:getName(row)
	return row
end

function machineWizard.wizard.pages.general:validate()
	return self.form:save()
end

function machineWizard.wizard:eventHandler(event)
	if event.type == 'nextView' and
		Util.find(self.pages, 'enabled', true) == self.pages.general then

		if self.pages.general.form:save() then
			local index = 2
			for _, page in pairs(self.pages) do
				if page.mtype == machineWizard.machine.mtype then
					page.index = index
					index = index + 1
				elseif page.index ~= 1 then
					page.index = nil
				end
			end
			self.pages.confirmation.index = index
			return UI.Wizard.eventHandler(self, event)
		end
	else
		return UI.Wizard.eventHandler(self, event)
	end
end

function machineWizard:enable(machine)
	self.machine = Util.deepCopy(machine)
	self.wizard.pages.general.form:setValues(self.machine)
	self.wizard.pages.general.form[1].shadowText = machine.name

	-- restore indices
	for _, page in pairs(self.wizard.pages) do
		if not page.oindex then
			page.oindex = page.index
		end
		page.index = page.oindex
	end

	UI.Page.enable(self)

	for _, v in pairs(self.wizard.pages) do
		if v.setMachine then
			v:setMachine(self.machine)
		end
	end
end

function machineWizard:eventHandler(event)
	if event.type == 'cancel' then
		UI:setPreviousPage()

	elseif event.type == 'accept' then

		-- todo: no need for calling this function - use validate instead
		for _, v in pairs(self.wizard.pages) do
			if v.save and v.index then  -- only save if the page was valid for this mtype
				v:save(self.machine)
			end
		end
		context.config.remoteDefaults[self.machine.name] =
			Util.prune(self.machine, function(v)
				if type(v) == 'boolean' then
					return v
				elseif type(v) == 'string' then
					return #v > 0
				elseif type(v) == 'table' then
					return not Util.empty(v)
				end
				return true
			end)
		Config.update('milo', context.config)

		UI:setPreviousPage()

	elseif event.type == 'enable_view' then
		local current = event.next or event.prev
		self.titleBar.title = current.title or 'Machine'
		self.titleBar:draw()

	elseif event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help)

	elseif event.type  == 'form_invalid' then
		self.notification:error(event.message)
		self:setFocus(event.field)

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:addPage('machines', machinesPage)
UI:addPage('machineWizard', machineWizard)
