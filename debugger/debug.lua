local Config = require('opus.config')
local Event  = require('opus.event')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local fs         = _G.fs
local getfenv    = _G.getfenv
local kernel     = _G.kernel
local multishell = _ENV.multishell
local shell      = _ENV.shell

local args = { ... }
local filename = shell.resolveProgram(table.remove(args, 1))

if not filename then
	error('file not found')
end

UI:disableEffects()

local config = Config.load('debugger')
if not config[filename] then
	config[filename] = { }
end

local breakpoints = config[filename]
local currentFile
local debugFile, debugLine

local debugger = kernel.getCurrent()
local client

local function startClient()
	local env = kernel.makeEnv(_ENV)
	currentFile = nil

	local clientId = multishell.openTab(nil, {
		env = env,
		title = fs.getName(filename):match('([^%.]+)'),
		args = args,
		fn = function()
			local dbg = require('debugger')
			local fn, msg = loadfile(filename, env)

			if not fn then
				error(msg, -1)
			end

			dbg.read = function(snapshot)
				os.sleep(0) -- not sure why, but we need a sleep before :resume
				-- directly resuming debugger routine to prevent
				-- serialization of the snapshot
				dbg.debugger:resume('debuggerX', dbg.debugger.uid, snapshot)
				local e, cmd, param
				repeat
					e, cmd, param = os.pullEvent('debugger')
				until e == 'debugger'
				return cmd, param
			end

			-- breakpoint table is shared across processes
			dbg.breakpoints = breakpoints
			dbg.debugger = debugger
			dbg.stopIn(fn)
			local s, m = dbg.call(fn, table.unpack(args))
			if not s then
				error(m, -1)
			end
		end,
	})
	client = kernel.find(clientId)
end

local romFiles = {
	load = function(self)
		local function recurse(dir)
			local files = fs.list(dir)
			for _,f in ipairs(files) do
				local fullName = fs.combine(dir, f)
				if fs.isDir(fullName) then
					recurse(fullName)
				else
					self.files[f] = fullName
				end
			end
		end
		recurse('rom/apis')
	end,
	get = function(self, file)
		return self.files[file]
	end,
	files = { },
}
romFiles:load()

local function loadSource(file)
	currentFile = romFiles:get(file) or file:match('@?(.*)')
	local src = { }
	local lines = Util.readLines(currentFile) or type(file) == 'string' and Util.split(file)

	if lines then
		for i = 1, #lines do
			table.insert(src, { line = i, source = lines[i] })
		end
	end

	return src
end

local function message(...)
	client:resume('debugger', ...)
end

local page = UI.Page {
	backgroundColor = 'black',

	container = UI.Window {
		y = 1, ey = '50%',
		tabs = UI.Tabs {
			ey = -2,
			locals = UI.Tab {
				title = 'Locals',
				index = 1,
				grid = UI.ScrollingGrid {
					disableHeader = true,
					unfocusedBackgroundSelectedColor = 'black',
					columns = {
						{ heading = 'Key',   key = 'name' },
						{ heading = 'Value', key = 'value', textColor = 'yellow' },
					},
					autospace = true,
					accelerators = {
						grid_select = 'show_variable',
					},
					getRowTextColor = function(self, row, selected)
						return row.type == 'U' and 'cyan'
							or row.type == 'V' and 'lime'
							or UI.Grid.getRowTextColor(self, row, selected)
					end,
				},
			},

			stack = UI.Tab {
				title = 'Stack',
				index = 3,
				grid = UI.ScrollingGrid {
					disableHeader = true,
					sortColumn = 'index',
					unfocusedBackgroundSelectedColor = 'black',
					columns = {
						{ key = 'index', width = 2 },
						{ heading = 'heading', key = 'desc' },
					},
					getRowTextColor = function(self, row, selected)
						return row.current and 'yellow'
							or UI.Grid.getRowTextColor(self, row, selected)
					end,
					eventHandler = function(self, event)
						if event.type == 'grid_select' then
							message('i', event.selected.index)
						else
							return UI.Grid.eventHandler(self, event)
						end
					end,
				},
			},

			env = UI.Tab {
				title = 'Env',
				index = 4,
				grid = UI.ScrollingGrid {
					disableHeader = true,
					autospace = true,
					unfocusedBackgroundSelectedColor = 'black',
					columns = {
						{ heading = 'Key',   key = 'name' },
						{ heading = 'Value', key = 'value', textColor = 'yellow' },
					},
					accelerators = {
						grid_select = 'show_variable',
					},
					sortCompare = function() end,
				},
			},

			breaks = UI.Tab {
				title = 'Breakpoints',
				index = 2,
				menuBar = UI.MenuBar {
					buttons = {
						{ text = 'Toggle', event = 'toggle' },
						{ text = 'Remove', event = 'remove' },
						{ text = 'Clear',  event = 'clear' },
					},
				},
				grid = UI.ScrollingGrid {
					y = 2,
					values = breakpoints,
					autospace = true,
					columns = {
						{ heading = 'Line', key = 'line', width = 5 },
						{ heading = 'Name', key = 'short' },
						{ heading = 'Path', key = 'path', textColor = 'lightGray' },
					},
					getRowTextColor = function(self, row, selected)
						return row.disabled and 'lightGray'
							or UI.Grid.getRowTextColor(self, row, selected)
					end,
				},
				eventHandler = function(self, event)
					if event.type == 'clear' then
						Util.clear(self.grid.values)
						self:emit({ type = 'update_breakpoints' })

					elseif event.type == 'toggle' then
						local bp = self.grid:getSelected()
						if bp then
							bp.disabled = not bp.disabled
							self:emit({ type = 'update_breakpoints' })
						end

					elseif event.type == 'grid_select' then
						self:emit({
							type = 'open_file',
							file = event.selected.file,
							line = event.selected.line,
						})

					elseif event.type == 'remove' then
						local bp = self.grid:getSelected()
						if bp then
							Util.removeByValue(self.grid.values, bp)
							self:emit({ type = 'update_breakpoints' })
						end

					end
					return UI.Tab.eventHandler(self, event)
				end,
			},
		},

		menuBar = UI.MenuBar {
			y = -1,
			buttons = {
				{ text = 'Continue', event = 'cmd', cmd = 'c' },
				{ text = 'Step',     event = 'cmd', cmd = 's' },
				{ text = 'Over',     event = 'cmd', cmd = 'n' },
				{ text = 'Out',      event = 'cmd', cmd = 'f' },
				{ text = 'Restart',  event = 'restart', width = 9, ex = -1 },
			},
		},
	},

	source = UI.ScrollingGrid {
		y = '50%', ey = -2,
		disableHeader = true,
		columns = {
			{ key = 'marker', width = 1 },
			{ key = 'line', textColor = 'cyan', width = 4 },
			{ heading = 'heading', key = 'source' },
		},
		accelerators = {
			t = 'toggle_enabled'
		},
		getDisplayValues = function(_, row)
			for _,v in pairs(breakpoints) do
				if v.file == currentFile and v.line == row.line then
					return {
						marker = v.disabled and 'x' or '!',
						line = row.line,
						source = row.source,
					}
				end
			end
			return row
		end,
		getRowTextColor = function(self, row, selected)
			return row.line == debugLine and currentFile == debugFile and 'yellow'
				or UI.Grid.getRowTextColor(self, row, selected)
		end,
		eventHandler = function(self, event)
			if event.type == 'grid_select' then
				self:emit({
					type = 'toggle_breakpoint',
					file = currentFile,
					line = event.selected.line,
				})
			elseif event.type == 'toggle_enabled' then
				local line = self:getSelected() and self:getSelected().line
				if line then
					for _,v in pairs(breakpoints) do
						if v.file == currentFile and v.line == line then
							v.disabled = not v.disabled
							self:emit({ type = 'update_breakpoints' })
							break
						end
					end
				end
			end
			return UI.Grid.eventHandler(self, event)
		end,
	},
	statusBar = UI.StatusBar {
		ex = -12, y = -1,
		backgroundColor = 'black',
		textColor = 'orange',
	},
	UI.FlatButton {
		y = -1, x = -5,
		textColor = 'orange',
		event = 'open',
		text = 'Open',
	},
	UI.FlatButton {
		y = -1, x = -10,
		textColor = 'orange',
		event = 'edit_file',
		text = 'Edit',
	},

	quick_open = UI.QuickSelect {
		y = '50%',
		modal = true,
		enable = function() end,
		show = function(self)
			UI.QuickSelect.enable(self)
			self:focusFirst()
			self:draw()
			self:addTransition('expandUp', { easing = 'outBounce', ticks = 12 })
		end,
		eventHandler = function(self, event)
			if event.type == 'select_cancel' then
				self:disable()
			elseif event.type == 'select_file' then
				self.parent:openFile(event.file)
				self:disable()
			end
			return UI.QuickSelect.eventHandler(self, event)
		end,
	},

	textDisplay = UI.SlideOut {
		ey = '50%',
		textArea = UI.TextArea {
			ey = -2,
		},
		UI.Button {
			x = '50%', y = -1,
			text = 'Ok',
			event = 'slide_hide',
		}
	},

	openFile = function(self, file, line)
		if file ~= currentFile then
			local src = loadSource(file)
			self.source:setValues(src)
		end
		if line then
			self.source:setIndex(#self.source.values)
			self.source:setIndex(math.max(1, line - 4))
		end
		self.source:setIndex(line or 1)

		if currentFile == debugFile then
			self.statusBar:setStatus(
				string.format('%s : %d', fs.getName(file), debugLine))
		else
			self.statusBar:setStatus(fs.getName(file))
		end
		self:draw()
	end,

	editFile = function(self, file)
		if fs.exists(file) then
			local line = self.source:getSelected().line
			multishell.openTab(_ENV, {
				path = 'sys/apps/shell.lua',
				args = { ('edit --line=%d %s'):format(line , file) },
				focused = true,
			})
		end
	end,

	eventHandler = function(self, event)
		if event.type == 'cmd' then
			self.statusBar:setStatus('Running...')
			message(event.element.cmd)

		elseif event.type == 'restart' then
			if kernel.find(client.uid) then
				client:resume('terminate')
			end
			startClient()

		elseif event.type == 'open' then
			self.quick_open:show()

		elseif event.type == 'edit_file' then
			self:editFile(currentFile)

		elseif event.type == 'open_file' then
			self:openFile(event.file, event.line)

		elseif event.type == 'update_breakpoints' then
			self.container.tabs.breaks.grid:update()
			self.container.tabs.breaks.grid:draw()
			self.source:draw()
			Config.update('debugger', config)

		elseif event.type == 'toggle_breakpoint' then
			for k,v in pairs(breakpoints) do
				if v.file == event.file and v.line == event.line then
					table.remove(breakpoints, k)
					self:emit({ type = 'update_breakpoints' })
					return
				end
			end

			table.insert(breakpoints, {
				file = event.file,
				line = event.line,
				short = fs.getName(event.file),
				path = fs.getDir(event.file),
			})

			self:emit({ type = 'update_breakpoints' })

		elseif event.type == 'show_variable' then
			if type(event.selected.raw) == 'table' then
				if event.selected.children then
					event.selected.children = nil
				else
					event.selected.children = { }
					local t = event.selected.raw
					for k,v in pairs(t) do
						local depth = event.selected.depth or 0
						table.insert(event.selected.children, {
							name = (' '):rep(depth + 2) .. tostring(k),
							value = tostring(v),
							raw = v,
							depth = depth + 2
						})
					end
					table.sort(event.selected.children, function(a, b) return a.name < b.name end)
				end
				local t = { }
				local function insert(values)
					for _,v in pairs(values) do
						table.insert(t, v)
						if v.children then
							insert(v.children)
						end
					end
				end
				insert(event.element.orig)
				event.element:setValues(t)
				event.element:draw()
			else
				self.textDisplay.textArea:setValue(event.selected.value)
				self.textDisplay:show()
			end
		end
		return UI.Page.eventHandler(self, event)
	end,
	enable = function(self)
		UI.Page.enable(self)
		startClient()
	end,
}

Event.on('debuggerX', function(_, uid, data)
	if uid == debugger.uid then
		kernel.raise(debugger.uid)

		-- local tab
		table.sort(data.locals, function(a, b) return a.name < b.name end)
		page.container.tabs.locals.grid:setValues(data.locals)
		page.container.tabs.locals.grid.orig = Util.shallowCopy(data.locals)

		-- env tab
		local t = { }
		for k,v in pairs(getfenv(data.info.func)) do
			table.insert(t, { name = k, value = tostring(v), raw = v })
		end
		table.sort(t, function(a, b) return a.name < b.name end)
		page.container.tabs.env.grid:setValues(t)
		page.container.tabs.env.grid.orig = Util.shallowCopy(t)

		debugLine = data.info.currentline
		debugFile = data.info.source:match('@?(.*)')

		-- source tab
		page:openFile(debugFile, debugLine)

		-- stack
		page.container.tabs.stack.grid:setValues(data.stack)

		page:draw()
		page:sync()
	end
end)

UI:setPage(page)
UI:start()

if kernel.find(client.uid) then
	client:resume('terminate')
end
