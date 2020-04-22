local Config   = require('opus.config')
local Event    = require('opus.event')
local itemDB   = require('core.itemDB')
local Socket   = require('opus.socket')
local UI       = require('opus.ui')
local Util     = require('opus.util')

local colors     = _G.colors
local fs         = _G.fs
local multishell = _ENV.multishell
local network    = _G.network
local os         = _G.os

UI:configure('Turtles', ...)

local config = { }
Config.load('Turtles', config)

local options = {
	turtle      = { arg = 'i', type = 'number', value = config.id or -1,
								 desc = 'Turtle ID' },
	tab         = { arg = 's', type = 'string', value = config.tab or 'Sel',
								 desc = 'Selected tab to display' },
	help        = { arg = 'h', type = 'flag',   value = false,
								 desc = 'Displays the options' },
}

local SCRIPTS_PATH = 'packages/common/etc/scripts'

local socket, turtle, page

page = UI.Page {
	coords = UI.Window {
		backgroundColor = colors.black,
		height = 3,
		marginTop = 1, marginLeft = 1,
		draw = function(self)
			local t = turtle
			self:clear()
			if t then
				self:setCursorPos(2, 2)
				local ind = 'GPS'
				if not t.point.gps then
					ind = 'REL'
				end
				self:print(string.format('%s : %d,%d,%d',
					ind, t.point.x, t.point.y, t.point.z))
			end
		end,
	},
	tabs = UI.Tabs {
		x = 1, y = 4, ey = -2,
		scripts = UI.ScrollingGrid {
			tabTitle = 'Run',
			backgroundColor = colors.cyan,
			columns = {
				{ heading = '', key = 'label' },
			},
			disableHeader = true,
			sortColumn = 'label',
			autospace = true,
			draw = function(self)
				Util.clear(self.values)
				local files = fs.list(SCRIPTS_PATH)
				for _,path in pairs(files) do
					table.insert(self.values, { label = path, path = fs.combine(SCRIPTS_PATH, path) })
				end
				self:update()
				UI.ScrollingGrid.draw(self)
			end,
			eventHandler = function(self, event)
				if event.type == 'grid_select' then
					page:runScript(event.selected.label)
				else
					return UI.ScrollingGrid.eventHandler(self, event)
				end
				return true
			end,
		},
		turtles = UI.ScrollingGrid {
			tabTitle = 'Select',
			backgroundColor = colors.cyan,
			columns = {
				{ heading = 'label',  key = 'label'    },
				{ heading = 'Dist',   key = 'distance' },
				{ heading = 'Status', key = 'status'   },
				{ heading = 'Fuel',   key = 'fuel'     },
			},
			disableHeader = true,
			sortColumn = 'label',
			autospace = true,
			getDisplayValues = function(_, row)
				row = Util.shallowCopy(row)
				if row.fuel then
					row.fuel = Util.toBytes(row.fuel)
				end
				if row.distance then
					row.distance = Util.round(row.distance, 1)
				end
				return row
			end,
			draw = function(self)
				Util.clear(self.values)
				for _,v in pairs(network) do
					if v.fuel then
						table.insert(self.values, v)
					end
				end
				self:update()
				UI.ScrollingGrid.draw(self)
			end,
			eventHandler = function(self, event)
				if event.type == 'grid_select' then
					turtle = event.selected
					config.id = event.selected.id
					Config.update('Turtles', config)
					multishell.setTitle(multishell.getCurrent(), turtle.label)
					if socket then
						socket:close()
						socket = nil
					end
				else
					return UI.ScrollingGrid.eventHandler(self, event)
				end
				return true
			end,
		},
		inventory = UI.ScrollingGrid {
			backgroundColor = colors.cyan,
			tabTitle = 'Inv',
			columns = {
				{ heading = '',          key = 'index', width = 2 },
				{ heading = '',          key = 'count', width = 2 },
				{ heading = 'Inventory', key = 'key' },
			},
			disableHeader = true,
			sortColumn = 'index',
			getRowTextColor = function(self, row, selected)
				if turtle and row.selected then
					return colors.yellow
				end
				return UI.ScrollingGrid.getRowTextColor(self, row, selected)
			end,
			draw = function(self)
				local t = turtle
				Util.clear(self.values)
				if t then
					for k,v in pairs(t.inv or { }) do -- new method (less data)
						local index, count = k:match('(%d+),(%d+)')
						v = {
							index = tonumber(index),
							key = v,
							count = tonumber(count),
						}
						table.insert(self.values, v)
					end

					for _,v in pairs(t.inventory or { }) do
						if v.count > 0 then
							table.insert(self.values, v)
						end
					end

					for _,v in pairs(self.values) do
						if v.index == t.slotIndex then
							v.selected = true
						end
						if v.key then
							v.key = itemDB:getName(v.key)
						end
					end
				end
				self:adjustWidth()
				self:update()
				UI.ScrollingGrid.draw(self)
			end,
			eventHandler = function(self, event)
				if event.type == 'grid_select' then
					local fn = string.format('turtle.select(%d)', event.selected.index)
					page:runFunction(fn)
				else
					return UI.ScrollingGrid.eventHandler(self, event)
				end
				return true
			end,
		},
--[[
		policy = UI.ScrollingGrid {
			tabTitle = 'Mod',
			backgroundColor = UI.TabBar.defaults.selectedBackgroundColor,
			columns = {
				{ heading = 'label', key = 'label' },
			},
			values = policies,
			disableHeader = true,
			sortColumn = 'label',
			autospace = true,
		},
		]]
		action = UI.Window {
			tabTitle = 'Action',
			backgroundColor = colors.cyan,
			moveUp = UI.Button {
				x = 5, y = 2,
				text = 'up',
				fn = 'turtle.up',
			},
			moveDown = UI.Button {
				x = 5, y = 4,
				text = 'dn',
				fn = 'turtle.down',
			},
			moveForward = UI.Button {
				x = 9, y = 3,
				text = 'f',
				fn = 'turtle.forward',
			},
			moveBack = UI.Button {
				x = 2, y = 3,
				text = 'b',
				fn = 'turtle.back',
			},
			turnLeft = UI.Button {
				x = 2, y = 6,
				text = 'lt',
				fn = 'turtle.turnLeft',
			},
			turnRight = UI.Button {
				x = 8, y = 6,
				text = 'rt',
				fn = 'turtle.turnRight',
			},
			info = UI.TextArea {
				x = 15, y = 2,
				inactive = true,
			}
		},
	},
	statusBar = UI.StatusBar {
		values = { },
		columns = {
			{ key = 'status'              },
			{ key = 'distance', width = 6 },
			{ key = 'fuel',     width = 6 },
		},
		draw = function(self)
			local t = turtle
			if t then
				self.values.status = t.status
				self.values.distance = t.distance and Util.round(t.distance, 2)
				self.values.fuel = Util.toBytes(t.fuel)
			end
			UI.StatusBar.draw(self)
		end,
	},
	notification = UI.Notification(),
	accelerators = {
		[ 'control-q' ] = 'quit',
	},
}

function page:runFunction(script, nowrap)
	for _ = 1, 2 do
		if not socket then
			socket = Socket.connect(turtle.id, 161)
		end

		if socket then
			if not nowrap then
				script = 'turtle.run(' .. script .. ')'
			end
			if socket:write({ type = 'scriptEx', args = script }) then
				local t = socket:read(3)
				if t then
					return table.unpack(t)
				end
				return false, 'Socket timeout'
			end
		end
		socket = nil
	end
	self.notification:error('Unable to connect')
end

function page:runScript(scriptName)
	if turtle then
		self.notification:info('Connecting')
		self:sync()

		local script = Util.readFile(fs.combine(SCRIPTS_PATH, scriptName))
		if not script then
			print('Unable to read script file')
		end

		local function processVariables()
			local variables = {
				COMPUTER_ID = os.getComputerID,
				GPS = function()
					local pt = require('opus.gps').getPoint()
					if not pt then
						error('Unable to determine location')
					end
					return _G.textutils.serialize(pt)
				end,
			}
			for k,v in pairs(variables) do
				local token = string.format('{%s}', k)
				if script:find(token, 1, true) then
					local s, m = pcall(v)
					if not s then
						self.notification:error(m)
						return
					end
					script = script:gsub(token, m)
				end
			end
			return true
		end

		if processVariables(script) then
			local socket = Socket.connect(turtle.id, 161)
			if not socket then
				self.notification:error('Unable to connect')
				return
			end
			socket:write({ type = 'script', args = script })
			socket:close()

			self.notification:success('Sent')
		end
	end
end

function page:showBlocks()
	local script = [[
		local function inspect(direction)
			local s,b = turtle['inspect' .. (direction or '')]()
			if not s then
				return 'minecraft:air:0'
			end
			return string.format('%s:%d', b.name, b.metadata)
		end

		local bu, bf, bd = inspect('Up'), inspect(), inspect('Down')
		return string.format('%s\n%s\n%s', bu, bf, bd)
	]]

	local s, m = self:runFunction(script, true)
	self.tabs.action.info:setText(s or m)
end

function page:eventHandler(event)
	if event.type == 'quit' then
		UI:quit()

	elseif event.type == 'tab_select' then
		config.tab = event.button.text
		Config.update('Turtles', config)

	elseif event.type == 'button_press' then
		if event.button.fn then
			self:runFunction(event.button.fn, event.button.nowrap)
			self:showBlocks()
		elseif event.button.script then
			self:runScript(event.button.script)
		end
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

if not Util.getOptions(options, { ... }, true) then
	return
end

if options.turtle.value >= 0 then
	for _ = 1, 10 do
		turtle = _G.network[options.turtle.value]
		if turtle then
			break
		end
		os.sleep(1)
	end
end

Event.onInterval(1, function()
	if turtle then
		--local t = _G.network[turtle.id]
		--turtle = t
		page:draw()
		page:sync()
	end
end)

if config.tab then
	page.tabs.tabBar:selectTab(config.tab)
end

UI:setPage(page)
UI:start()
