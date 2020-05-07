local Array  = require('opus.array')
local Config = require('opus.config')
local fuzzy  = require('opus.fuzzy')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local device     = _G.device
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell
local term       = _G.term
local textutils  = _G.textutils

local _format   = string.format
local _rep      = string.rep
local _sub      = string.sub
local _concat   = table.concat
local _insert   = table.insert
local _remove   = table.remove
local _unpack   = table.unpack

local config = Config.load('editor')

local x, y      = 1, 1
local w, h      = term.getSize()
local scrollX   = 0
local scrollY   = 0
local lastPos   = { x = 1, y = 1 }
local tLines    = { }
local fileInfo
local actions
local lastSave
local dirty     = { y = 1, ey = h }
local mark      = { }
local searchPattern
local undo      = { chain = { }, redo = { } }

h = h - 1

local bgColor = 'gray'
local color = {
	text    = '0',
	keyword = '2',
	comment = 'd',
	string  = '1',
	mark    = '8',
	bg      = '7',
}

if not term.isColor() then
	bgColor = 'black'
	color = {
		text    = '0',
		keyword = '8',
		comment = '8',
		string  = '8',
		mark    = '7',
		bg      = 'f',
	}
end

local keyMapping = {
	-- movement
	up                        = 'up',
	down                      = 'down',
	left                      = 'left',
	right                     = 'right',
	pageUp                    = 'page_up',
	[ 'control-b'           ] = 'page_up',
	pageDown                  = 'page_down',
	home                      = 'home',
	[ 'end'                 ] = 'toend',
	[ 'control-home'        ] = 'top',
	[ 'control-end'         ] = 'bottom',
	[ 'control-right'       ] = 'word',
	[ 'control-left'        ] = 'backword',
	[ 'scroll_up'           ] = 'scroll_up',
	[ 'control-up'          ] = 'scroll_up',
	[ 'scroll_down'         ] = 'scroll_down',
	[ 'control-down'        ] = 'scroll_down',
	[ 'mouse_click'         ] = 'go_to',
	[ 'control-g'           ] = 'goto_line',

	-- marking
	[ 'shift-up'            ] = 'mark_up',
	[ 'shift-down'          ] = 'mark_down',
	[ 'shift-left'          ] = 'mark_left',
	[ 'shift-right'         ] = 'mark_right',
	[ 'mouse_drag'          ] = 'mark_to',
	[ 'shift-mouse_click'   ] = 'mark_to',
	[ 'control-a'           ] = 'mark_all',
	[ 'control-shift-right' ] = 'mark_word',
	[ 'control-shift-left'  ] = 'mark_backword',
	[ 'shift-end'           ] = 'mark_end',
	[ 'shift-home'          ] = 'mark_home',
	[ 'mouse_down'          ] = 'mark_anchor',
	[ 'mouse_doubleclick'   ] = 'mark_current_word',
	[ 'mouse_tripleclick'   ] = 'mark_line',

	-- editing
	delete                    = 'delete',
	backspace                 = 'backspace',
	enter                     = 'enter',
	char                      = 'char',
	paste                     = 'paste',
	tab                       = 'tab',
	[ 'control-z'           ] = 'undo',
	[ 'control-Z'           ] = 'redo',
	[ 'control-space'       ] = 'autocomplete',
	[ 'control-shift-space' ] = 'peripheral',

	-- copy/paste
	[ 'control-x'           ] = 'cut',
	[ 'control-c'           ] = 'copy',
	[ 'control-y'           ] = 'paste_internal',

	-- file
	[ 'control-s'           ] = 'save',
	[ 'control-S'           ] = 'save_as',
	[ 'control-q'           ] = 'exit',
	[ 'control-enter'       ] = 'run',
	[ 'control-p'           ] = 'quick_open',

	-- search
	[ 'control-f'           ] = 'find_prompt',
	[ 'control-slash'       ] = 'find_prompt',
	[ 'control-n'           ] = 'find_next',

	-- misc
	[ 'control-i'           ] = 'status',
	[ 'control-r'           ] = 'refresh',
}

local page = UI.Page {
	menuBar = UI.MenuBar {
		transitionHint = 'slideLeft',
		buttons = {
			{ text = 'File', dropdown = {
				{ text = 'New             ', event = 'menu_action', action = 'file_new' },
				{ text = 'Open...         ', event = 'menu_action', action = 'file_open' },
				{ text = 'Quick Open... ^p', event = 'menu_action', action = 'quick_open' },
				{ text = 'Recent...       ', event = 'menu_action', action = 'recent' },
				{ spacer = true },
				{ text = 'Save          ^s', event = 'menu_action', action = 'save' },
				{ text = 'Save As...    ^S', event = 'menu_action', action = 'save_as' },
				{ spacer = true },
				{ text = 'Quit          ^q', event = 'menu_action', action = 'exit' },
			} },
			{ text = 'Edit', dropdown = {
				{ text = 'Cut           ^x', event = 'menu_action', action = 'cut' },
				{ text = 'Copy          ^c', event = 'menu_action', action = 'copy' },
				{ text = 'Paste      ^y,^V', event = 'menu_action', action = 'paste_internal' },
				{ spacer = true },
				{ text = 'Find...       ^f', event = 'menu_action', action = 'find_prompt' },
				{ text = 'Find Next     ^n', event = 'menu_action', action = 'find_next' },
				{ spacer = true },
				{ text = 'Go to line... ^g', event = 'menu_action', action = 'goto_line' },
				{ text = 'Mark all      ^a', event = 'menu_action', action = 'mark_all' },
			} },
			{ text = 'Code', dropdown = {
				{ text = 'Complete   ^space', event = 'menu_action', action = 'autocomplete' },
				{ text = 'Run        ^enter', event = 'menu_action', action = 'run' },
				{ spacer = true },
				{ text = 'Peripheral ^SPACE', event = 'menu_action', action = 'peripheral' },
			} },
		},
		status = UI.Text {
			textColor = 'gray',
			x = -9, width = 9,
			align = 'right',
		},
	},
	gotoLine = UI.MiniSlideOut {
		x = -15, y = -2,
		label = 'Line',
		lineNo = UI.TextEntry {
			x = 7, width = 7,
			limit = 5,
			transform = 'number',
			accelerators = {
				[ 'enter' ] = 'accept',
			},
		},
		show = function(self)
			self.lineNo:reset()
			UI.MiniSlideOut.show(self)
		end,
		eventHandler = function(self, event)
			if event.type == 'accept' then
				if self.lineNo.value then
					actions.process('go_to', 1, self.lineNo.value)
				end
				self:hide()
				return true
			end
			return UI.MiniSlideOut.eventHandler(self, event)
		end,
	},
	search = UI.MiniSlideOut {
		x = '50%', y = -2,
		label = 'Find',
		search = UI.TextEntry {
			x = 7, ex = -3,
			accelerators = {
				[ 'enter' ] = 'accept',
			},
		},
		show = function(self)
			self.search:markAll()
			UI.MiniSlideOut.show(self)
		end,
		eventHandler = function(self, event)
			if event.type == 'accept' then
				local text = self.search.value
				if text and #text > 0 then
					searchPattern = text:lower()
					if searchPattern then
						actions.unmark()
						actions.process('find', searchPattern, x)
					end
				end
				self:hide()
				return true
			end
			return UI.MiniSlideOut.eventHandler(self, event)
		end,
	},
	save_as = UI.MiniSlideOut {
		x = '30%', y = -2,
		label = 'Save',
		filename = UI.TextEntry {
			x = 7, ex = -3,
			accelerators = {
				[ 'enter' ] = 'accept',
			},
		},
		show = function(self)
			self.filename:setValue(fileInfo.path)
			self.filename:setPosition(#self.filename.value)
			UI.MiniSlideOut.show(self)
		end,
		eventHandler = function(self, event)
			if event.type == 'accept' then
				local text = self.filename.value
				if text and #text > 0 then
					actions.save('/' .. text)
				end
				self:hide()
				return true
			end
			return UI.MiniSlideOut.eventHandler(self, event)
		end,
	},
	unsaved = UI.Question {
		x = -25, y = -2,
		label = 'Save',
		cancel = UI.Button {
			x = 16,
			text = 'Cancel',
			backgroundColor = 'primary',
			event = 'question_cancel',
		},
		show = function(self, action)
			self.action = action
			UI.MiniSlideOut.show(self)
		end,
		eventHandler = function(self, event)
			if event.type == 'question_yes' then
				if actions.save() then
					self:hide()
					actions.process(self.action)
				end
			elseif event.type == 'question_no' then
				actions.process(self.action, true)
				self:hide()
			elseif event.type == 'question_cancel' then
				self:hide()
			end
			return UI.MiniSlideOut.eventHandler(self, event)
		end,
	},
	file_open = UI.FileSelect {
		modal = true,
		enable = function() end,
		show = function(self)
			UI.FileSelect.enable(self, fs.getDir(fileInfo.path))
			self:focusFirst()
			self:draw()
			self:addTransition('expandUp', { easing = 'outBounce', ticks = 12 })
		end,
		eventHandler = function(self, event)
			if event.type == 'select_cancel' then
				self:disable()
			elseif event.type == 'select_file' then
				self:disable()
				actions.process('open', event.file)
			end
			return UI.FileSelect.eventHandler(self, event)
		end,
	},
	recent = UI.SlideOut {
		grid = UI.Grid {
			x = 2, y = 2, ey = -4, ex = -2,
			columns = {
				{ key = 'name', heading = 'Name' },
				{ key = 'dir', heading = 'Directory', textColor = 'lightGray' },
			},
			accelerators = {
				backspace = 'slide_hide',
			},
		},
		cancel = UI.Button {
			x = -9, y = -2,
			text = 'Cancel',
			event = 'slide_hide',
		},
		show = function(self)
			local t = { }
			for _,v in pairs(config.recent or { }) do
				table.insert(t, { name = fs.getName(v), dir = fs.getDir(v), path = v })
			end
			self.grid:setValues(t)
			self.grid:setIndex(1)
			UI.SlideOut.show(self)
			self:addTransition('expandUp', { easing = 'outBounce', ticks = 12 })
		end,
		eventHandler = function(self, event)
			if event.type == 'grid_select' then
				actions.process('open', event.selected.path)
				self:hide()
				return true
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	quick_open = UI.SlideOut {
		filter_entry = UI.TextEntry {
			x = 2, y = 2, ex = -2,
			shadowText = 'File name',
			accelerators = {
				[ 'enter' ] = 'accept',
				[ 'up' ] = 'grid_up',
				[ 'down' ] = 'grid_down',
			},
		},
		grid = UI.ScrollingGrid {
			x = 2, y = 3, ex = -2, ey = -4,
			disableHeader = true,
			columns = {
				{ key = 'name' },
				{ key = 'dir', textColor = 'lightGray' },
			},
			accelerators = {
				grid_select = 'accept',
			},
		},
		cancel = UI.Button {
			x = -9, y = -2,
			text = 'Cancel',
			event = 'slide_hide',
		},
		apply_filter = function(self, filter)
			local t = { }
			if filter then
				filter = filter:lower()
				self.grid.sortColumn = 'score'
				self.grid.inverseSort = true

				for _,v in pairs(self.listing) do
					v.score = fuzzy(v.lname, filter)
					if v.score then
						_insert(t, v)
					end
				end
			else
				self.grid.sortColumn = 'lname'
				self.grid.inverseSort = false
				t = self.listing
			end

			self.grid:setValues(t)
			self.grid:setIndex(1)
		end,
		show = function(self)
			local listing = { }
			local function recurse(dir)
				local files = fs.list(dir)
				for _,f in ipairs(files) do
					local fullName = fs.combine(dir, f)
					if fs.native.isDir(fullName) then -- skip virtual dirs
						if f ~= '.git' then recurse(fullName) end
					else
						_insert(listing, {
							name = f,
							dir = dir,
							lname = f:lower(),
							fullName = fullName,
						})
					end
				end
			end
			recurse('')
			self.listing = listing
			self:apply_filter()
			self.filter_entry:reset()
			UI.SlideOut.show(self)
			self:addTransition('expandUp', { easing = 'outBounce', ticks = 12 })
		end,
		eventHandler = function(self, event)
			if event.type == 'grid_up' then
				self.grid:emit({ type = 'scroll_up' })

			elseif event.type == 'grid_down' then
				self.grid:emit({ type = 'scroll_down' })

			elseif event.type == 'accept' then
				local sel = self.grid:getSelected()
				if sel then
					actions.process('open', sel.fullName)
					self:hide()
				end

			elseif event.type == 'text_change' then
				self:apply_filter(event.text)
				self.grid:draw()

			else
				return UI.SlideOut.eventHandler(self, event)
			end
			return true
		end,
	},
	completions = UI.SlideOut {
		x = -12, y = 2,
		transitionHint = 'slideLeft',
		grid = UI.Grid {
			x = 2, y = 2, ey = -2,
			columns = {
				{ key = 'text', heading = 'Completion' },
			},
			accelerators = {
				[ ' ' ] = 'down',
				backspace = 'slide_hide',
			},
		},
		cancel = UI.Button {
			y = -1, x = -9,
			text = 'Cancel',
			backgroundColor = 'black',
			backgroundFocusColor = 'black',
			textColor = 'lightGray',
			event = 'slide_hide',
		},
		show = function(self, values)
			local m = 12
			for _, v in pairs(values) do
				m = #v.text > m and #v.text or m
			end
			m = m + 3
			m = m > self.parent.width and self.parent.width or m
			self.ox = -m
			self:resize()
			self.grid:setValues(values)
			self.grid:setIndex(1)
			UI.SlideOut.show(self)
		end,
		eventHandler = function(self, event)
			if event.type == 'grid_select' then
				actions.process('insertText', x, y, event.selected.complete)
				self:hide()
				return true
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	peripheral = UI.SlideOut {
		x = '20%', y = 2,
		transitionHint = 'slideLeft',
		grid1 = UI.Grid {
			x = 2, y = 2, ey = 5,
			sortColumn = 'name',
			columns = {
				{ key = 'name', heading = 'Peripheral' },
			},
			accelerators = {
				[ ' ' ] = 'down',
				backspace = 'slide_hide',
				grid_focus_row = 'select_peripheral',
				grid_select = 'complete',
			},
			scan = function(self)
				self.values = { }
				for k, v in pairs(device) do
					table.insert(self.values, { name = k, complete = 'peripheral.wrap("' .. v.side .. '")' })
				end
			end,
			postInit = function(self)
				self:scan()
			end,
		},
		grid2 = UI.Grid {
			x = 2, y = 6, ey = -2,
			sortColumn = 'method',
			columns = {
				{ key = 'method', heading = 'Method' },
			},
			accelerators = {
				[ ' ' ] = 'down',
				backspace = 'slide_hide',
				grid_select = 'complete',
			},
			showMethods = function(self)
				local dev = device[self.parent.grid1:getSelected().name]
				local t = { }
				if dev then
					pcall(function()
						local docs = dev.getDocs and dev.getDocs()
						for k, v in pairs(dev) do
							if type(v) == 'function' then
								local m = docs and docs[k] and docs[k]:match('^function%((.+)%).+')
								table.insert(t, { method = k, complete = k .. '(' .. (m or '') .. ')' })
							end
						end
					end)
				end
				self:setValues(t)
			end,
			enable = function(self)
				self:showMethods()
				UI.Grid.enable(self)
			end,
		},
		cancel = UI.Button {
			y = -1, x = -9,
			text = 'Cancel',
			backgroundColor = 'black',
			backgroundFocusColor = 'black',
			textColor = 'lightGray',
			event = 'slide_hide',
		},
		eventHandler = function(self, event)
			if event.type == 'complete' then
				actions.process('insertText', x, y, event.selected.complete)
				actions.process('left')
				self:hide()
				return true
			elseif event.type == 'select_peripheral' then
				self.grid2:showMethods()
				self.grid2:setIndex(1)
				self.grid2:update()
				self.grid2:draw()
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	editor = UI.Window {
		y = 2,
		backgroundColor = bgColor,
		transitionHint = 'slideRight',
		cursorBlink = true,
		focus = function(self)
			if self.focused then
				self:setCursorPos(x - scrollX, y - scrollY)
			end
		end,
		resize = function(self)
			UI.Window.resize(self)

			w, h = self.width, self.height
			actions.set_cursor(x, y)
			actions.dirty_all()
			actions.redraw()
		end,
		setCursorPos = function(self, cx, cy)
			self.cursorBlink = cy >= 1 and cy <= self.height
			UI.Window.setCursorPos(self, cx, cy)
		end,
		draw = function()
			actions.redraw()
		end,
		eventHandler = function(_, event)
			if event.ie then
				local action, param, param2
				local ie = event.ie

				if ie.code == 'char' then
					action = keyMapping.char
					param = ie.ch

				elseif ie.code == "mouse_click" or
					ie.code == 'mouse_drag' or
					ie.code == 'shift-mouse_click' or
					ie.code == 'mouse_down' or
					ie.code == 'mouse_doubleclick' then

					action = keyMapping[ie.code]
					param = ie.x + scrollX
					param2 = ie.y + scrollY

				elseif event.type == 'paste' then
					action = keyMapping.paste
					param = event.text

				else
					action = keyMapping[ie.code]
				end

				if action then
					actions.process(action, param, param2)
					return true
				end
			end
		end,
	},
	notification = UI.Notification { },
	enable = function(self)
		UI.Page.enable(self)
		self:setFocus(self.editor)
	end,
	checkFocus = function(self)
		if not self.focused or not self.focused.enabled then
			-- if no current focus, set it to the editor
			self:setFocus(self.editor)
		end
	end,
	eventHandler = function(self, event)
		if event.type == 'menu_action' then
			actions.process(event.element.action)
			return true
		end
		return UI.Page.eventHandler(self, event)
	end,
}

local function getFileInfo(path)
	path = fs.combine('/', path)

	local fi = {
		path = path,
		isNew = not fs.exists(path),
		dirExists = fs.exists(fs.getDir(path)),
		isReadOnly = fs.isReadOnly(path),
	}

	if path ~= config.filename then
		config.filename = path
		config.recent = config.recent or { }

		Array.removeByValue(config.recent, path)
		table.insert(config.recent, 1, path)
		while #config.recent > 10 do
			table.remove(config.recent)
		end

		Config.update('editor', config)
	end

	if multishell then
		multishell.setTitle(multishell.getCurrent(), fs.getName(fi.path))
	end

	return fi
end

local keywords = Util.transpose {
	'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if',
	'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while'
}

local function writeHighlighted(sLine, ny, dy)
	local buffer = { fg = { }, text = { } }

	local function tryWrite(line, regex, fgcolor)
		local match = line:match(regex)
		if match then
			local fg = type(fgcolor) == "string" and fgcolor or fgcolor(match)
			_insert(buffer.text, match)
			_insert(buffer.fg, _rep(fg, #match))
			return _sub(line, #match + 1)
		end
		return nil
	end

	while #sLine > 0 do
		sLine =
			-- tryWrite(sLine, "^[%\26]", '7' ) or
			tryWrite(sLine, "^%-%-%[%[.-%]%]", color.comment ) or
			tryWrite(sLine, "^%-%-.*",         color.comment ) or
			tryWrite(sLine, "^\".-[^\\]\"",    color.string  ) or
			tryWrite(sLine, "^\'.-[^\\]\'",    color.string  ) or
			tryWrite(sLine, "^%[%[.-%]%]",     color.string  ) or
			tryWrite(sLine, "^[%w_]+", function(match)
				return keywords[match] and color.keyword or color.text
			end) or
			tryWrite(sLine, "^[^%w_]", color.text)
	end

	buffer.fg = _concat(buffer.fg) .. '7'
	buffer.text = _concat(buffer.text) .. '\183'

	if mark.active and ny >= mark.y and ny <= mark.ey then
		local sx = ny == mark.y and mark.x or 1
		local ex = ny == mark.ey and mark.ex or #buffer.text
		buffer.bg = _rep(color.bg, sx - 1) ..
					_rep(color.mark, ex - sx) ..
					_rep(color.bg, #buffer.text - ex + 1)
	else
		buffer.bg = _rep(color.bg, #buffer.text)
	end

	page.editor:blit(1 - scrollX, dy, buffer.text, buffer.bg, buffer.fg)
end

local function redraw()
	if dirty.y > 0 then
		for dy = 1, h do
			local sLine = tLines[dy + scrollY]
			if sLine and #sLine > 0 then
				if dy + scrollY >= dirty.y and dy + scrollY <= dirty.ey then
					page.editor:clearLine(dy)
					writeHighlighted(sLine, dy + scrollY, dy)
				end
			else
				page.editor:clearLine(dy)
			end
		end
	end

	local modifiedIndicator = undo.chain[#undo.chain] == lastSave and ' ' or '*'
	page.menuBar.status.value = _format('%d:%d%s', y, x, modifiedIndicator)
	page.menuBar.status:draw()

	if page.editor.focused then
		page.editor:setCursorPos(x - scrollX, y - scrollY)
	end

	dirty.y, dirty.ey = 0, 0
end

local function nextWord(line, cx)
	local result = { line:find("(%w+)", cx) }
	if #result > 1 and result[2] > cx then
		return result[2] + 1
	elseif #result > 0 and result[1] == cx then
		result = { line:find("(%w+)", result[2] + 1) }
		if #result > 0 then
			return result[1]
		end
	end
end

actions = {
	info = function(pattern, ...)
		page.notification:info(_format(pattern, ...))
	end,

	error = function(pattern, ...)
		page.notification:error(_format(pattern, ...))
	end,

	undo = function()
		local last = _remove(undo.chain)
		if last then
			undo.active = true
			table.insert(undo.redo, { })
			for i = #last, 1, -1 do
				local u = last[i]
				actions[u.action](_unpack(u.args))
			end
			undo.active = false
		else
			actions.info('already at oldest change')
		end
	end,

	undo_add = function(entry)
		if undo.active then
			local last = undo.redo[#undo.redo]
			table.insert(last, entry)
		else
			if not undo.redo_active then
				undo.redo = { }
			end
			local last = undo.chain[#undo.chain]
			if last and undo.continue then
				table.insert(last, entry)
			else
				_insert(undo.chain, { entry })
			end
		end
	end,

	redo = function()
		local last = _remove(undo.redo)
		if last then
			-- too many flags !
			undo.redo_active = true
			undo.continue = false
			for i = #last, 1, -1 do
				local u = last[i]
				actions[u.action](_unpack(u.args))
				undo.continue = true
			end
			undo.redo_active = false
		else
			actions.info('already at newest change')
		end
	end,

	autocomplete = function()
		local sLine = tLines[y]:sub(1, x - 1):match("[a-zA-Z0-9_%.]+$")
		local results = sLine and textutils.complete(sLine, _ENV) or { }

		if #results == 0 then
			actions.error('no completions available')

		elseif #results == 1 then
			actions.insertText(x, y, results[1])

		elseif #results > 1 then
			local prefix = sLine:match('^.+%.(.*)$') or sLine
			for i = 1, #results do
				results[i] = {
					text = prefix .. results[i],
					complete = results[i],
				}
			end
			page.completions:show(results)
		end
	end,

	peripheral = function()
		page.peripheral:show()
	end,

	refresh = function()
		actions.dirty_all()
		mark.continue = mark.active
		actions.info('refreshed')
	end,

	goto_line = function()
		page.gotoLine:show()
	end,

	find = function(pattern, sx)
		local nLines = #tLines
		for i = 1, nLines + 1 do
			local ny = y + i - 1
			if ny > nLines then
				ny = ny - nLines
			end
			local nx = tLines[ny]:lower():find(pattern, sx, true)
			if nx then
				if ny < y or ny == y and nx <= x then
					actions.info('search hit BOTTOM, continuing at TOP')
				end
				actions.go_to(nx, ny)
				actions.mark_to(nx + #pattern, ny)
				return
			end
			sx = 1
		end
		actions.error('pattern not found')
	end,

	find_next = function()
		if searchPattern then
			actions.unmark()
			actions.find(searchPattern, x + 1)
		end
	end,

	find_prompt = function()
		page.search:show()
	end,

	quick_open = function(force)
		if not force and undo.chain[#undo.chain] ~= lastSave then
			page.unsaved:show('quick_open')
		else
			page.quick_open:show()
		end
	end,

	file_open = function(force)
		if not force and undo.chain[#undo.chain] ~= lastSave then
			page.unsaved:show('file_open')
		else
			page.file_open:show()
		end
	end,

	recent = function(force)
		if not force and undo.chain[#undo.chain] ~= lastSave then
			page.unsaved:show('recent')
		else
			page.recent:show()
		end
	end,

	file_new = function(force)
		if not force and undo.chain[#undo.chain] ~= lastSave then
			page.unsaved:show('file_new')
		else
			actions.open('/untitled.txt')
		end
	end,

	open = function(filename)
		if not actions.load(filename) then
			actions.error('unable to load file')
		end
	end,

	load = function(path)
		if not path or (fs.exists(path) and fs.isDir(path)) then
			return false
		end
		fileInfo = getFileInfo(path)

		x, y = 1, 1
		scrollX, scrollY = 0, 0
		lastPos   = { x = 1, y = 1 }
		lastSave  = nil
		dirty     = { y = 1, ey = h }
		mark      = { }
		undo      = { chain = { }, redo = { } }

		tLines = Util.readLines(fileInfo.path) or { }
		if #tLines == 0 then
			_insert(tLines, '')
		end

		--[[
		local function detabify(l)
			return l:gsub('\26\26', '\9'):gsub('\26', '\9')
		end ]]

		-- since we can't handle tabs, convert them to spaces :(
		local t1, t2 = ' ', '  '
		local function tabify(l)
			repeat
				local i = l:find('\9')
				if i then
					local tabs = (i - 1) % 2 == 0 and t2 or t1
					l = l:sub(1, i - 1) .. tabs .. l:sub(i + 1)
				end
			until not i
			return l
		end

		for k, v in pairs(tLines) do
			tLines[k] = tabify(v)
		end

		local name = fileInfo.path
		if fileInfo.isNew then
			if not fileInfo.dirExists then
				actions.info('"%s" [New DIRECTORY]', name)
			else
				actions.info('"%s" [New File]', name)
			end
		elseif fileInfo.isReadOnly then
			actions.info('"%s" [readonly] %dL, %dC',
				name, #tLines, fs.getSize(fileInfo.path))
		else
			actions.info('"%s" %dL, %dC',
				name, #tLines, fs.getSize(fileInfo.path))
		end

		return true
	end,

	save = function(filename)
		filename = filename or fileInfo.path
		if fs.isReadOnly(filename) then
			actions.error("access denied")
		else
			local s, m = pcall(function()
				if not Util.writeLines(filename, tLines) then
					error("Failed to open " .. filename)
				end
			end)

			if s then
				lastSave = undo.chain[#undo.chain]
				fileInfo = getFileInfo(filename)
				actions.info('"%s" %dL, %dC written',
					 fileInfo.path, #tLines, fs.getSize(fileInfo.path))
				return true
			else
				actions.error(m)
			end
		end
	end,

	save_as = function()
		page.save_as:show()
	end,

	exit = function(force)
		if not force and undo.chain[#undo.chain] ~= lastSave then
			page.unsaved:show('exit')
		else
			UI:quit()
		end
	end,

	run = function()
		if not multishell then
			actions.error('open available with multishell')
			return
		end
		if undo.chain[#undo.chain] == lastSave then
			local nTask = shell.openTab(fileInfo.path)
			if nTask then
				shell.switchTab(nTask)
			else
				actions.error("error starting Task")
			end
		else
			local fn, msg = load(_concat(tLines, '\n'), fileInfo.path)
			if fn then
				multishell.openTab({
					fn = fn,
					focused = true,
					title = fs.getName(fileInfo.path),
				})
			else
				local ln = msg:match(':(%d+):')
				if ln and tonumber(ln) then
					actions.go_to(1, tonumber(ln))
				end
				actions.error(msg)
			end
		end
	end,

	status = function()
		local modified = undo.chain[#undo.chain] == lastSave and '' or '[Modified] '
		actions.info('"%s" %s%d lines --%d%%--',
				 fileInfo.path, modified, #tLines,
				 math.floor((y - 1) / (#tLines - 1) * 100))
	end,

	dirty_line = function(dy)
		if dirty.y == 0 then
			dirty.y = dy
			dirty.ey = dy
		else
			dirty.y = math.min(dirty.y, dy)
			dirty.ey = math.max(dirty.ey, dy)
		end
	end,

	dirty_range = function(dy, dey)
		actions.dirty_line(dy)
		actions.dirty_line(dey or #tLines)
	end,

	dirty = function()
		actions.dirty_line(y)
	end,

	dirty_all = function()
		actions.dirty_line(1)
		actions.dirty_line(#tLines)
	end,

	mark_begin = function()
		actions.dirty()
		if not mark.active then
			mark.active = true
			mark.anchor = { x = x, y = y }
		end
	end,

	mark_finish = function()
		if y == mark.anchor.y then
			if x == mark.anchor.x then
				mark.active = false
			else
				mark.x = math.min(mark.anchor.x, x)
				mark.y = y
				mark.ex = math.max(mark.anchor.x, x)
				mark.ey = y
			end
		elseif y < mark.anchor.y then
			mark.x = x
			mark.y = y
			mark.ex = mark.anchor.x
			mark.ey = mark.anchor.y
		else
			mark.x = mark.anchor.x
			mark.y = mark.anchor.y
			mark.ex = x
			mark.ey = y
		end
		actions.dirty()
		mark.continue = mark.active
	end,

	unmark = function()
		if mark.active then
			actions.dirty_range(mark.y, mark.ey)
			mark.active = false
		end
	end,

	mark_anchor = function(nx, ny)
		actions.go_to(nx, ny)
		actions.unmark()
		actions.mark_begin()
		actions.mark_finish()
	end,

	mark_to = function(nx, ny)
		actions.mark_begin()
		actions.go_to(nx, ny)
		actions.mark_finish()
	end,

	mark_up = function()
		actions.mark_begin()
		actions.up()
		actions.mark_finish()
	end,

	mark_right = function()
		actions.mark_begin()
		actions.right()
		actions.mark_finish()
	end,

	mark_down = function()
		actions.mark_begin()
		actions.down()
		actions.mark_finish()
	end,

	mark_left = function()
		actions.mark_begin()
		actions.left()
		actions.mark_finish()
	end,

	mark_line = function()
		actions.home()
		actions.mark_begin()
		actions.toend()
		actions.right()
		actions.mark_finish()
	end,

	mark_word = function()
		actions.mark_begin()
		actions.word()
		actions.mark_finish()
	end,

	mark_current_word = function(cx, cy)
		local index = 1
		actions.go_to(cx, cy)
		while true do
			local s, e = tLines[y]:find('%w+', index)
			if not s or s - 1 > x then
				break
			end
			if x >= s and x <= e then
				x = s
				actions.mark_begin()
				x = e + 1
				actions.mark_finish()
				x, y = cx, cy
				break
			end
			index = e + 1
		end
	end,

	mark_backword = function()
		actions.mark_begin()
		actions.backword()
		actions.mark_finish()
	end,

	mark_home = function()
		actions.mark_begin()
		actions.home()
		actions.mark_finish()
	end,

	mark_end = function()
		actions.mark_begin()
		actions.toend()
		actions.mark_finish()
	end,

	mark_all = function()
		mark.anchor = { x = 1, y = 1 }
		mark.active = true
		mark.continue = true
		mark.x = 1
		mark.y = 1
		mark.ey = #tLines
		mark.ex = #tLines[mark.ey] + 1
		actions.dirty_all()
	end,

	set_cursor = function()
		lastPos.x = x
		lastPos.y = y

		local screenX = x - scrollX
		local screenY = y - scrollY

		if screenX < 1 then
			scrollX = math.max(0, x - 4)
			actions.dirty_all()
		elseif screenX > w then
			scrollX = x - w + 3
			actions.dirty_all()
		end

		if screenY < 1 then
			scrollY = y - 1
			actions.dirty_all()
		elseif screenY > h then
			scrollY = y - h
			actions.dirty_all()
		end
	end,

	top = function()
		actions.go_to(1, 1)
	end,

	bottom = function()
		y = #tLines
		x = #tLines[y] + 1
	end,

	up = function()
		if y > 1 then
			x = math.min(x, #tLines[y - 1] + 1)
			y = y - 1
		end
	end,

	down = function()
		if y < #tLines then
			x = math.min(x, #tLines[y + 1] + 1)
			y = y + 1
		end
	end,

	tab = function()
		if mark.active then
			actions.delete()
		end
		actions.insertText(x, y, '  ')
	end,

	page_up = function()
		actions.go_to(x, y - h)
	end,

	page_down = function()
		actions.go_to(x, y + h)
	end,

	home = function()
		x = 1
	end,

	toend = function()
		x = #tLines[y] + 1
	end,

	left = function()
		if x > 1 then
			x = x - 1
		elseif y > 1 then
			x = #tLines[y - 1] + 1
			y = y - 1
		else
			return false
		end
		return true
	end,

	right = function()
		if x < #tLines[y] + 1 then
			x = x + 1
		elseif y < #tLines then
			x = 1
			y = y + 1
		end
	end,

	word = function()
		local nx = nextWord(tLines[y], x)
		if nx then
			x = nx
		elseif x < #tLines[y] + 1 then
			x = #tLines[y] + 1
		elseif y < #tLines then
			x = 1
			y = y + 1
		end
	end,

	backword = function()
		if x == 1 then
			actions.left()
		else
			local sLine = tLines[y]
			local lx = 1
			while true do
				local nx = nextWord(sLine, lx)
				if not nx or nx >= x then
					break
				end
				lx = nx
			end
			if not lx then
				x = 1
			else
				x = lx
			end
		end
	end,

	insertText = function(sx, sy, text)
		x = sx
		y = sy
		local sLine = tLines[y]

		if not text:find('\n') then
			tLines[y] = sLine:sub(1, x - 1) .. text .. sLine:sub(x)
			actions.dirty_line(y)
			x = x + #text
		else
			local lines = Util.split(text)
			local remainder = sLine:sub(x)
			tLines[y] = sLine:sub(1, x - 1) .. lines[1]
			actions.dirty_range(y, #tLines + #lines)
			x = x + #lines[1]
			for k = 2, #lines do
				y = y + 1
				_insert(tLines, y, lines[k])
				x = #lines[k] + 1
			end
			tLines[y] = tLines[y]:sub(1, x) .. remainder
		end

		actions.undo_add(
			{ action = 'deleteText', args = { sx, sy, x, y } })
	end,

	deleteText = function(sx, sy, ex, ey)
		x = sx
		y = sy

		local text = actions.copyText(sx, sy, ex, ey)
		actions.undo_add(
			{ action = 'insertText', args = { sx, sy, text } })

		local front = tLines[sy]:sub(1, sx - 1)
		local back = tLines[ey]:sub(ex, #tLines[ey])
		for _ = 2, ey - sy + 1 do
			_remove(tLines, y + 1)
		end
		tLines[y] = front .. back
		if sy ~= ey then
			actions.dirty_range(y)
		else
			actions.dirty()
		end
	end,

	copyText = function(csx, csy, cex, cey)
		local count = 0
		local lines = { }

		for cy = csy, cey do
			local line = tLines[cy]
			if line then
				local cx = 1
				local ex = #line
				if cy == csy then
					cx = csx
				end
				if cy == cey then
					ex = cex - 1
				end
				local str = line:sub(cx, ex)
				count = count + #str
				_insert(lines, str)
			end
		end
		return _concat(lines, '\n'), count
	end,

	delete = function()
		if mark.active then
			actions.deleteText(mark.x, mark.y, mark.ex, mark.ey)
		else
			local nLimit = #tLines[y] + 1
			if x < nLimit then
				actions.deleteText(x, y, x + 1, y)
			elseif y < #tLines then
				actions.deleteText(x, y, 1, y + 1)
			end
		end
	end,

	backspace = function()
		if mark.active or actions.left() then
			actions.delete()
		end
	end,

	enter = function()
		local sLine = tLines[y]
		local _,spaces = sLine:find("^[ ]+")
		if not spaces then
			spaces = 0
		end
		spaces = math.min(spaces, x - 1)
		if mark.active then
			actions.delete()
		end
		actions.insertText(x, y, '\n' .. _rep(' ', spaces))
	end,

	char = function(ch)
		if mark.active then
			actions.delete()
		end
		actions.insertText(x, y, ch)
	end,

	copy_marked = function()
		local text = actions.copyText(mark.x, mark.y, mark.ex, mark.ey)
		os.queueEvent('clipboard_copy', text)
		actions.info('shift-^v to paste')
	end,

	cut = function()
		if mark.active then
			actions.copy_marked()
			actions.delete()
		end
	end,

	copy = function()
		if mark.active then
			actions.copy_marked()
			mark.continue = true
		end
	end,

	paste = function(text)
		if mark.active then
			actions.delete()
		end
		if text then
			actions.insertText(x, y, text)
			actions.info('%d chars added', #text)
		else
			actions.info('clipboard empty')
		end
	end,

	paste_internal = function()
		os.queueEvent('clipboard_paste')
	end,

	go_to = function(cx, cy)
		y = math.min(math.max(cy, 1), #tLines)
		x = math.min(math.max(cx, 1), #tLines[y] + 1)
	end,

	scroll_up = function()
		if scrollY > 0 then
			scrollY = scrollY - 1
			actions.dirty_all()
		end
		mark.continue = mark.active
	end,

	scroll_down = function()
		local nMaxScroll = #tLines - h
		if scrollY < nMaxScroll then
			scrollY = scrollY + 1
			actions.dirty_all()
		end
		mark.continue = mark.active
	end,

	redraw = function()
		redraw()
	end,

	process = function(action, ...)
		if not actions[action] then
			error('Invaid action: ' .. action)
		end

		local wasMarking = mark.continue
		mark.continue = false

		-- for undo purposes, treat tab and enter as char actions
		local a = (action == 'tab' or action == 'enter') and 'char' or action
		undo.continue = a == undo.lastAction

		actions[action](...)

		undo.lastAction = a

		if x ~= lastPos.x or y ~= lastPos.y then
			actions.set_cursor()
		end
		if not mark.continue and wasMarking then
			actions.unmark()
		end

		actions.redraw()
	end,
}

local args = { ... }
local filename = args[1] and shell.resolve(args[1])
if not (actions.load(filename) or actions.load(config.filename) or actions.load('untitled.txt')) then
	error('Error opening file')
end

UI:setPage(page)
local s, m = pcall(function() UI:start() end)
if not s then
	actions.save('/crash.txt')
	print('Editor has crashed. File saved as /crash.txt')
	error(m)
end
