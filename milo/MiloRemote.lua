local Config = require('opus.config')
local Event  = require('opus.event')
local fuzzy  = require('opus.fuzzy')
local Sound  = require('opus.sound')
local Socket = require('opus.socket')
local sync   = require('opus.sync').sync
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors     = _G.colors
local fs         = _G.fs
local peripheral = _G.peripheral
local shell      = _ENV.shell

local configName = ({...})[1]
local configPath = 'miloRemote' .. (configName and "_"..configName or "")

local context = {
	state = Config.load(configPath, { displayMode = 0, deposit = true }),
	configPath = configPath,
	responseHandlers = { },
}

local depositMode = {
	[ true  ] = { text = '\25',  textColor = colors.black, help = 'Deposit enabled' },
	[ false ] = { text = '\215', textColor = colors.red,   help = 'Deposit disabled' },
}

local displayModes = {
	[0] = { text = 'A', help = 'Showing all items' },
	[1] = { text = 'I', help = 'Showing inventory items' },
}

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{
				text = 'Refresh',
				x = -12,
				event = 'refresh'
			},
			{
				name = 'config',
				text = '\187',
				x = -3,
			},
		},
		infoBar = UI.StatusBar {
			x = 1, ex = -16,
			backgroundColor = colors.lightGray,
		},
	},
	grid = UI.Grid {
		y = 2, ey = -2,
		columns = {
			{ heading = ' Qty', key = 'count'       , width = 4, align = 'right' },
			{ heading = 'Name', key = 'displayName' },
		},
		values = { },
		sortColumn = context.state.sortColumn or 'count',
		inverseSort = context.state.inverseSort,
		help = '^(s)tack, ^(a)ll'
	},
	statusBar = UI.Window {
		y = -1,
		filter = UI.TextEntry {
			x = 1, ex = -13,
			limit = 50,
			shadowText = 'filter',
			backgroundColor = 'primary',
			backgroundFocusColor = 'primary',
			accelerators = {
				[ 'enter' ] = 'eject',
				[ 'up' ] = 'grid_up',
				[ 'down' ] = 'grid_down',
				[ 'control-a' ] = 'eject_all',
			},
		},
		amount = UI.TextEntry {
			x = -12, ex = -7,
			limit = 4,
			shadowText = '1',
			shadowTextColor = colors.gray,
			backgroundColor = colors.black,
			backgroundFocusColor = colors.black,
			accelerators = {
				[ 'enter' ] = 'eject_specified',
				[ 'control-a' ] = 'eject_all',
			},
			help = 'Request amount',
		},
		depositToggle = UI.Button {
			x = -6,
			event = 'toggle_deposit',
			text = '\215',
		},
		display = UI.Button {
			x = -3,
			event = 'toggle_display',
			text = displayModes[context.state.displayMode].text,
			help = displayModes[context.state.displayMode].help,
		},
	},
	notification = UI.Notification {
		anchor = 'top',
	},
	accelerators = {
		r = 'refresh',
		[ 'control-r' ] = 'refresh',
		[ 'control-e' ] = 'eject',
		[ 'control-s' ] = 'eject_stack',
		[ 'control-a' ] = 'eject_all',
		[ 'control-q' ] = 'quit',
	},
	items = { },
}

local function getPlayerName()
	local neural = peripheral.find('neuralInterface')

	if neural and neural.getName then
		return neural.getName()
	end
end

function page.grid:getRowTextColor(row, selected)
	if row.is_craftable then
		return colors.yellow
	end
	if row.has_recipe then
		return colors.cyan
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.count = row.count > 0 and Util.toBytes(row.count) or ''
	return row
end

function page.grid:sortCompare(a, b)
	if self.sortColumn ~= 'displayName' then
		if a[self.sortColumn] == b[self.sortColumn] then
			if self.inverseSort then
				return a.displayName > b.displayName
			end
			return a.displayName < b.displayName
		end
		if a[self.sortColumn] == 0 then
			return self.inverseSort
		end
		if b[self.sortColumn] == 0 then
			return not self.inverseSort
		end
		return a[self.sortColumn] < b[self.sortColumn]
	end
	return UI.Grid.sortCompare(self, a, b)
end

function page.grid:eventHandler(event)
	if event.type == 'grid_sort' then
		context.state.sortColumn = event.sortColumn
		context.state.inverseSort = event.inverseSort
		Config.update(configPath, context.state)
	end
	return UI.Grid.eventHandler(self, event)
end

function page:transfer(item, count, msg)
	context:sendRequest({ request = 'transfer', item = item, count = count }, msg)
end

function page:eventHandler(event)
	if event.type == 'quit' then
		UI:quit()

	elseif event.type == 'setup' then
		self.setup.form:setValues(context.state)
		self.setup:show()

	elseif event.type == 'toggle_deposit' then
		context.state.deposit = not context.state.deposit
		Util.merge(self.statusBar.depositToggle, depositMode[context.state.deposit])
		self.statusBar:draw()
		context:setStatus(depositMode[context.state.deposit].help)
		context:notifyInfo(depositMode[context.state.deposit].help)
		Config.update(configPath, context.state)

	elseif event.type == 'focus_change' then
		context:setStatus(event.focused.help)

	elseif event.type == 'eject' or event.type == 'grid_select' then
		local item = self.grid:getSelected()
		if item then
			self:transfer(item, 1, 'requesting 1 ...')
		end

	elseif event.type == 'eject_stack' then
		local item = self.grid:getSelected()
		if item then
			self:transfer(item, 'stack', 'requesting stack ...')
		end

	elseif event.type == 'eject_all' then
		local item = self.grid:getSelected()
		if item then
			self:transfer(item, 'all', 'requesting all ...')
		end

	elseif event.type == 'eject_specified' then
		local item = self.grid:getSelected()
		local count = tonumber(self.statusBar.amount.value)
		if item and count then
			self.statusBar.amount:reset()
			self:setFocus(self.statusBar.filter)
			self:transfer(item, count, 'requesting ' .. count .. ' ...')
		else
			Sound.play('entity.villager.no')
			context:notifyError('nope ...')
		end

	elseif event.type == 'plugin' then
		event.button.callback(context)

	elseif event.type == 'rescan' then
		self:setFocus(self.statusBar.filter)
		self:refresh('scan')
		self.grid:draw()

	elseif event.type == 'grid_up' then
		self.grid:emit({ type = 'scroll_up' })

	elseif event.type == 'grid_down' then
		self.grid:emit({ type = 'scroll_down' })

	elseif event.type == 'refresh' then
		self:setFocus(self.statusBar.filter)
		self:refresh('list')
		self.grid:draw()

	elseif event.type == 'toggle_display' then
		context.state.displayMode = (context.state.displayMode + 1) % 2
		Util.merge(event.button, displayModes[context.state.displayMode])
		event.button:draw()
		self:applyFilter()
		context:setStatus(event.button.help)
		context:notifyInfo(event.button.help)
		self.grid:draw()
		Config.update(configPath, context.state)

	elseif event.type == 'text_change' and event.element == self.statusBar.filter then
		self.filter = event.text or ''
		if #self.filter == 0 then
			self.filter = nil
		end
		self:applyFilter()
		self.grid:setIndex(1)
		self.grid:draw()

	else
		UI.Page.eventHandler(self, event)
	end
	return true
end

function page:enable()
	self:setFocus(self.statusBar.filter)
	Util.merge(self.statusBar.depositToggle, depositMode[context.state.deposit])
	UI.Page.enable(self)
	if not context.state.server then
		self.setup.form:setValues(context.state)
		self.setup:show()
	end
	Event.onTimeout(.1, function()
		self:refresh('list')
		self.grid:draw()
		self:sync()
	end)
end

local function splitKey(key)
	local t = Util.split(key, '(.-):')

	local item = { }
	if t[3] then
		item.nbt = t[3]
	end
	t[3] = nil
	item.name = table.concat(t, ':')
	return item
end

function page:expandList(list)
	local t = { }
	for k,v in pairs(list) do
		local item = splitKey(k)
		item.has_recipe, item.count, item.displayName = v:match('(%d+):(%d+):(.+)')
		item.count = tonumber(item.count) or 0
		item.lname = item.displayName:lower()
		item.has_recipe = item.has_recipe == '1'
		t[k] = item
	end
	return t
end

function page:refresh(requestType)
	context:sendRequest({ request = requestType }, 'refreshing...')
end

function page:applyFilter()
	local function filterItems(t, filter, displayMode)
		self.grid.sortColumn = context.state.sortColumn or 'count'
		self.grid.inverseSort = context.state.inverseSort

		if filter then
			local r = { }
			filter = filter:lower()
			self.grid.sortColumn = 'score'
			self.grid.inverseSort = true

			for _,v in pairs(t) do
				v.score = fuzzy(v.lname, filter)
				if v.score then
					if v.count > 0 then
						v.score = v.score + .2
					end
					table.insert(r, v)
				end
			end
			return r

		elseif displayMode > 0 then
			local r = { }

			for _,v in pairs(t) do
				if v.count > 0 then
					table.insert(r, v)
				end
			end
			return r
		end

		return t
	end
	local t = filterItems(self.items, self.filter, context.state.displayMode)
	self.grid:setValues(t)
end

context.page = page

function context:setStatus(status)
	page.menuBar.infoBar.values = status
	page.menuBar.infoBar:draw()
	page:sync()
end

function context:notifySuccess(status)
	page.notification:success(status)
	page:sync()
end

function context:notifyInfo(status)
	page.notification:info(status)
	page:sync()
end

function context:notifyError(status)
	page.notification:error(status)
	page:sync()
end

local function processMessages(s)
	Event.addRoutine(function()
		s.co = coroutine.running()
		repeat
			local response = s:read()
			if not response then
				break
			end
			local h = context.responseHandlers[response.type]
			if h then
				h(response)
			end
			if response.msg then
				context:notifyInfo(response.msg)
			end
		until not s.connected

		s:close()
		s = nil
		context:notifyError('disconnected ...')
		Sound.play('entity.villager.no')
	end)
end

function context:sendRequest(data, statusMsg)
	if not context.state.server then
		self:notifyError('Invalid configuration')
		return
	end

	local player = getPlayerName()
	if not player then
		self:notifyError('Missing neural or introspection')
		return
	end

	local success
	sync(page, function()
		local msg
		for _ = 1, 2 do
			if not context.socket or not context.socket.connected then
				self:notifyInfo('connecting ...')
				context.socket, msg = Socket.connect(context.state.server, 4242)
				if context.socket then
					context.socket:write(player)
					local r = context.socket:read(2)
					if r and not r.msg then
						self:notifySuccess('connected ...')
						processMessages(context.socket)
					else
						msg = r and r.msg or 'Timed out'
						context.socket:close()
						context.socket = nil
					end
				end
			end
			if context.socket then
				if statusMsg then
					self:notifyInfo(statusMsg)
				end
				if context.socket:write(data) then
					success = true
					return
				end
				context.socket:close()
				context.socket = nil
			end
		end
		self:notifyError(msg or 'Failed to connect')
	end)

	return success
end

function context:getState(key)
	return self.state[key]
end

function context:setState(key, value)
	self.state[key] = value
	Config.update(configPath, self.state)
end

context.responseHandlers['received'] = function(response)
	Sound.play('entity.item.pickup')
	local ritem = page.items[response.key]
	if ritem then
		ritem.count = response.count
		if page.enabled then
			page.grid:draw()
			page:sync()
		end
	end
end

context.responseHandlers['list'] = function(response)
	page.items = page:expandList(response.list)
	page:applyFilter()
	if page.enabled then
		page.grid:draw()
		page.grid:sync()
	end
end

context.responseHandlers['transfer'] = function(response)
	if response.count > 0 then
		Sound.play('entity.item.pickup')
		local item = page.items[response.key]
		if item then
			item.count = response.current
			if page.enabled then
				page.grid:draw()
				page:sync()
			end
		end
	end
	if response.craft then
		if response.craft > 0 then
			context:notifyInfo(response.craft .. ' crafting ...')
		elseif response.craft + response.count < response.requested then
			if response.craft + response.count == 0 then
				Sound.play('entity.villager.no')
			end
			context:notifyInfo((response.craft + response.count) .. ' available ...')
		end
	end
end

local function loadDirectory(dir)
	local dropdown = {
		{ text = 'Setup', event = 'setup' },
		{ spacer = true },
		{
			text = 'Rescan storage',
			event = 'rescan',
			help = 'Rescan all inventories'
		},
	}

	for _, file in pairs(fs.list(dir)) do
		local s, m = Util.run(_ENV, fs.combine(dir, file), context)
		if not s and m then
			_G.printError('Error loading: ' .. file)
			error(m or 'Unknown error')
		elseif s and m then
			table.insert(dropdown, {
				text = m.menuItem,
				event = 'plugin',
				callback = m.callback,
			})
		end
	end
	page.menuBar.config.dropdown = dropdown
end

local programDir = fs.getDir(shell.getRunningProgram())
loadDirectory(fs.combine(programDir, 'plugins/remote'))

UI:setPage(page)
UI:start()

if context.socket then
	context.socket:close()
end
