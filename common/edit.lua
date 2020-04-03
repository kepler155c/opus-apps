local UI = require('opus.ui')

local colors     = _G.colors
local fs         = _G.fs
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell
local term       = _G.term
local textutils  = _G.textutils

local x, y      = 1, 1
local w, h      = term.getSize()
local scrollX   = 0
local scrollY   = 0
local lastPos   = { x = 1, y = 1 }
local tLines    = { }
local fileInfo
local lastAction
local actions
local sStatus = ''
local lastSave
local dirty     = { y = 1, ey = h }
local mark      = { }
local searchPattern
local undo      = { chain = { }, pointer = 0 }
local complete  = { }
local page

h = h - 2

local color = {
	textColor       = '0',
	keywordColor    = '4',
	commentColor    = 'd',
	stringColor     = 'e',
	bgColor         = colors.black,
	highlightColor  = colors.orange,
	cursorColor     = colors.lime,
	errorBackground = colors.red,
}

if not term.isColor() then
	color = {
		textColor       = '0',
		keywordColor    = '8',
		commentColor    = '8',
		stringColor     = '8',
		bgColor         = colors.black,
		highlightColor  = colors.lightGray,
		cursorColor     = colors.white,
		errorBackground = colors.gray,
	}
end

local keyMapping = {
	-- movement
	up                        = 'up',
	down                      = 'down',
	left                      = 'left',
	right                     = 'right',
	pageUp                    = 'pageUp',
	[ 'control-b'           ] = 'pageUp',
	pageDown                  = 'pageDown',
--  [ 'control-f'           ] = 'pageDown',
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

	-- editing
	delete                    = 'delete',
	backspace                 = 'backspace',
	enter                     = 'enter',
	char                      = 'char',
	paste                     = 'paste',
	tab                       = 'tab',
	[ 'control-z'           ] = 'undo',
	[ 'control-space'       ] = 'autocomplete',

	-- copy/paste
	[ 'control-x'           ] = 'cut',
	[ 'control-c'           ] = 'copy',
--	[ 'control-shift-paste' ] = 'paste_internal',

	-- file
	[ 'control-s'           ] = 'save',
	[ 'control-S'           ] = 'save_as',
	[ 'control-q'           ] = 'exit',
	[ 'control-enter'       ] = 'run',

	-- search
	[ 'control-f'           ] = 'find_prompt',
	[ 'control-slash'       ] = 'find_prompt',
	[ 'control-n'           ] = 'find_next',

	-- misc
--	[ 'control-g'           ] = 'status',
	[ 'control-r'           ] = 'refresh',
}

page = UI.Page {
	menuBar = UI.MenuBar {
		transitionHint = 'slideLeft',
		buttons = {
			{ text = 'File', dropdown = {
				{ text = 'Save          ^s', event = 'menu_action', action = 'save' },
				{ text = 'Save As...    ^S', event = 'menu_action', action = 'save_as', noFocus = true },
				{ spacer = true },
				{ text = 'Run',              event = 'menu_action', action = 'run' },
				{ spacer = true },
				{ text = 'Quit          ^q', event = 'menu_action', action = 'exit', noFocus = true },
			} },
			{ text = 'Edit', dropdown = {
				{ text = 'Cut           ^x', event = 'menu_action', action = 'cut'    },
				{ text = 'Copy          ^c', event = 'menu_action', action = 'copy'   },
				{ text = 'Paste         ^V', event = 'paste_internal' },
				{ spacer = true },
				{ text = 'Find...       ^f', event = 'menu_action', action = 'find_prompt', noFocus = true },
				{ text = 'Find Next     ^n', event = 'menu_action', action = 'find_next' },
				{ spacer = true },
				{ text = 'Go to line... ^g', event = 'menu_action', action = 'goto_line', noFocus = true },
				{ text = 'Mark all      ^a', event = 'menu_action', action = 'mark_all' },

			} },
		},
	},
	gotoLine = UI.SlideOut {
		x = -15, height = 1, y = -2,
		noFill = true,
		close = UI.Button {
			x = -1,
			backgroundColor = colors.cyan,
			backgroundFocusColor = colors.cyan,
			text = 'x',
			event = 'slide_hide',
			noPadding = true,
		},
		label = UI.Text {
			x = 2,
			value = 'Line',
		},
		lineNo = UI.TextEntry {
			x = 7, width = 7,
			limit = 5,
			backgroundFocusColor = colors.gray,
			backgroundColor = colors.gray,
			transform = 'number',
			accelerators = {
				[ 'enter' ] = 'accept',
			},
		},
		disable = function(self)
			UI.SlideOut.disable(self)
			self:setFocus(page.editor)
		end,
		show = function(self)
			self.lineNo:reset()
			UI.SlideOut.show(self)
			self:addTransition('slideLeft', { easing = 'outBounce' })
		end,
		eventHandler = function(self, event)
			if event.type == 'accept' then
				if self.lineNo.value then
					actions.process('go_to', 1, self.lineNo.value)
				end
				self:hide()
				return true
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	search = UI.SlideOut {
		x = -20, height = 1, y = -2,
		noFill = true,
		close = UI.Button {
			x = -1,
			backgroundColor = colors.cyan,
			backgroundFocusColor = colors.cyan,
			text = 'x',
			event = 'slide_hide',
			noPadding = true,
		},
		label = UI.Text {
			x = 2,
			value = 'Find',
		},
		search = UI.TextEntry {
			x = 7, width = 12,
			limit = 512,
			markBackgroundColor = colors.lightGray,
			backgroundFocusColor = colors.gray,
			backgroundColor = colors.gray,
			accelerators = {
				[ 'enter' ] = 'accept',
			},
		},
		disable = function(self)
			UI.SlideOut.disable(self)
			self:setFocus(page.editor)
		end,
		show = function(self)
			self.search:markAll()
			UI.SlideOut.show(self)
			self:addTransition('slideLeft', { easing = 'outBounce' })
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
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	save_as = UI.SlideOut {
		x = -24, height = 1, y = -2,
		noFill = true,
		close = UI.Button {
			x = -1,
			backgroundColor = colors.cyan,
			backgroundFocusColor = colors.cyan,
			text = 'x',
			event = 'slide_hide',
			noPadding = true,
		},
		label = UI.Text {
			x = 2,
			value = 'Save',
		},
		filename = UI.TextEntry {
			x = 7, width = 16,
			limit = 512,
			markBackgroundColor = colors.lightGray,
			backgroundFocusColor = colors.gray,
			backgroundColor = colors.gray,
			accelerators = {
				[ 'enter' ] = 'accept',
			},
		},
		disable = function(self)
			UI.SlideOut.disable(self)
			self:setFocus(page.editor)
		end,
		show = function(self)
			self.filename.value = fileInfo.abspath
			if self.filename.value then
				self.filename:setPosition(#self.filename.value)
			end
			UI.SlideOut.show(self)
			self:addTransition('slideLeft', { easing = 'outBounce' })
		end,
		eventHandler = function(self, event)
			if event.type == 'accept' then
				local text = self.filename.value
				if text and #text > 0 then
					actions.save(shell.resolve(text))
				end
				self:hide()
				return true
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	quit = UI.SlideOut {
		x = -26, height = 1, y = -2,
		noFill = true,
		close = UI.Button {
			x = -1,
			backgroundColor = colors.cyan,
			backgroundFocusColor = colors.cyan,
			text = 'x',
			event = 'slide_hide',
			noPadding = true,
		},
		label = UI.Text {
			x = 2,
			value = 'Save',
		},
		save = UI.Button {
			x = 7,
			text = 'Yes',
			backgroundColor = colors.cyan,
			event = 'save_yes',
		},
		quit = UI.Button {
			x = 13,
			text = 'No',
			backgroundColor = colors.cyan,
			event = 'save_no',
		},
		cancel = UI.Button {
			x = 18,
			text = 'Cancel',
			backgroundColor = colors.cyan,
			event = 'save_cancel',
		},
		disable = function(self)
			UI.SlideOut.disable(self)
			self:setFocus(page.editor)
		end,
		show = function(self)
			UI.SlideOut.show(self)
			self:addTransition('slideLeft', { easing = 'outBounce' })
		end,
		eventHandler = function(self, event)
			if event.type == 'save_yes' then
				if actions.save() then
					UI:quit()
				end
			elseif event.type == 'save_no' then
				UI:quit()
			elseif event.type == 'save_cancel' then
				self:hide()
			end
			return UI.SlideOut.eventHandler(self, event)
		end,
	},
	editor = UI.Window {
		y = 2, ey = -2,
		backgroundColor = colors.black,
		transitionHint = 'slideRight',
		focus = function(self)
			if self.focused then
				page.editor:setCursorPos(x - scrollX, y - scrollY)
				self:setCursorBlink(true)
			else
				self:setCursorBlink(false)
			end
		end,
		resize = function(self)
			UI.Window.resize(self)

			w, h = self.width, self.height
			actions.setCursor(x, y)
			actions.dirty_all()
			actions.redraw()
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
					--ie.code == 'mouse_up' or
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
	statusBar = UI.StatusBar {
		transitionHint = 'slideLeft',
		backgroundColor = colors.gray,
		columns = {
			{ key = 'general'        },
			{ key = 'pos', width = 6, fg = colors.orange },
		},
	},
	enable = function(self)
		UI.Page.enable(self)
		self:setFocus(page.editor)
	end,
	eventHandler = function(self, event)
		if event.type == 'paste_internal' then
			self:setFocus(page.editor)
			os.queueEvent('clipboard_paste')
			return true

		elseif event.type == 'menu_action' then
			actions.process(event.element.action)
			if not event.element.noFocus then -- hacky
				self:setFocus(self.editor)
			end
			return true
		end
		return UI.Page.eventHandler(self, event)
	end,
}

local messages = {
	wrapped = 'search hit BOTTOM, continuing at TOP',
}
if w < 32 then
	messages = {
		wrapped = 'search wrapped',
	}
end

local function getFileInfo(path)
	local abspath = shell.resolve(path)

	local fi = {
		abspath = abspath,
		path = path,
		isNew = not fs.exists(abspath),
		dirExists = fs.exists(fs.getDir(abspath)),
		modified = false,
	}
	if fi.isDir then
		fi.isReadOnly = true
	else
		fi.isReadOnly = fs.isReadOnly(fi.abspath)
	end
_G._p = fi
	return fi
end

local function setStatus(pattern, ...)
	sStatus = string.format(pattern, ...)
	page.statusBar.textColor = colors.white
	page.statusBar:setValue('general', sStatus)
	page.statusBar:draw()
end

local function setError(pattern, ...)
	sStatus = string.format(pattern, ...)
	page.statusBar.textColor = color.highlightColor
	page.statusBar:setValue('general', sStatus)
	page.statusBar:draw()
end

local function load(path)
	fileInfo = getFileInfo(path)

	tLines = {}
	if fs.exists(fileInfo.abspath) then
		local file = io.open(fileInfo.abspath, "r")
		local sLine = file:read()
		while sLine do
			table.insert(tLines, sLine)
			sLine = file:read()
		end
		file:close()
	end

	if #tLines == 0 then
		table.insert(tLines, '')
	end

	local name = fileInfo.path
	if w < 32 then
		name = fs.getName(fileInfo.path)
	end
	if fileInfo.isNew then
		if not fileInfo.dirExists then
			setStatus('"%s" [New DIRECTORY]', name)
		else
			setStatus('"%s" [New File]', name)
		end
	elseif fileInfo.isReadOnly then
		setStatus('"%s" [readonly] %dL, %dC',
					name, #tLines, fs.getSize(fileInfo.abspath))
	else
		setStatus('"%s" %dL, %dC',
					name, #tLines, fs.getSize(fileInfo.abspath))
	end
end

local function save( _sPath )
	-- Create intervening folder
	local sDir = _sPath:sub(1, _sPath:len() - fs.getName(_sPath):len() )
	if not fs.exists( sDir ) then
		fs.makeDir( sDir )
	end

	-- Save
	local file = nil
	local function innerSave()
		file = fs.open( _sPath, "w" )
		if file then
			for _,sLine in ipairs( tLines ) do
				file.write(sLine .. "\n")
			end
		else
			error( "Failed to open ".._sPath )
		end
	end

	local ok, err = pcall( innerSave )
	if file then
		file.close()
	end
	return ok, err
end

local function split(str, pattern)
	pattern = pattern or "(.-)\n"
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub(pattern, helper)))
	return t
end

local tKeywords = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"]= true,
	["while"] = true,
}

local function writeHighlighted(sLine, ny, dy)
	local buffer = {
		fg = '',
		text = '',
	}

	local function tryWrite(line, regex, fgcolor)
		local match = line:match(regex)
		if match then
			local fg
			if type(fgcolor) == "string" then
				fg = fgcolor
			else
				fg = fgcolor(match)
			end
			buffer.text = buffer.text .. match
			buffer.fg = buffer.fg .. string.rep(fg, #match)
			return line:sub(#match + 1)
		end
		return nil
	end

	while #sLine > 0 do
		sLine =
			tryWrite(sLine, "^%-%-%[%[.-%]%]", color.commentColor ) or
			tryWrite(sLine, "^%-%-.*",         color.commentColor ) or
			tryWrite(sLine, "^\".-[^\\]\"",    color.stringColor  ) or
			tryWrite(sLine, "^\'.-[^\\]\'",    color.stringColor  ) or
			tryWrite(sLine, "^%[%[.-%]%]",     color.stringColor  ) or
			tryWrite(sLine, "^[%w_]+", function(match)
				if tKeywords[match] then
					return color.keywordColor
				end
				return color.textColor
			end) or
			tryWrite(sLine, "^[^%w_]", color.textColor)
	end

	buffer.fg = buffer.fg .. '7'
	buffer.text = buffer.text .. '\183'

	if mark.active and ny >= mark.y and ny <= mark.ey then
		local sx = 1
		if ny == mark.y then
			sx = mark.x
		end
		local ex = #buffer.text
		if ny == mark.ey then
			ex = mark.ex
		end
		buffer.bg = string.rep('f', sx - 1) ..
					string.rep('7', ex - sx) ..
					string.rep('f', #buffer.text - ex + 1)

	else
		buffer.bg = string.rep('f', #buffer.text)
	end

	page.editor:blit(1 - scrollX, dy, buffer.text, buffer.bg, buffer.fg)
end

local function redraw()
	if dirty.y > 0 then
		for dy = 1, h do

			local sLine = tLines[dy + scrollY]
			if sLine ~= nil then
				if dy + scrollY >= dirty.y and dy + scrollY <= dirty.ey then
					page.editor:clearLine(dy)
					writeHighlighted(sLine, dy + scrollY, dy)
				end
			else
				page.editor:clearLine(dy)
			end
		end
	end

	-- Draw status
	if #sStatus == 0 then
		page.statusBar:setValue('general', '')
		page.statusBar:draw()
	end

	if not (w < 32 and #sStatus > 0) then
		local modifiedIndicator = ''
		if undo.chain[#undo.chain] ~= lastSave then
			modifiedIndicator = '*'
		end

		local str = string.format(' %d:%d%s',
			y, x, modifiedIndicator)

		page.statusBar:setValue('pos', str)
		page.statusBar.columns[2].width = #str
		page.statusBar:adjustWidth()
		page.statusBar:draw()
	end

	if page.editor.focused then
		page.editor:setCursorPos(x - scrollX, y - scrollY)
	end

	dirty.y, dirty.ey = 0, 0
	if #sStatus > 0 then
		sStatus = ''
	end
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
	undo = function()
		local last = table.remove(undo.chain)
		if last then
			undo.active = true
			actions[last.action](table.unpack(last.args))
			undo.active = false
		else
			setStatus('Already at oldest change')
		end
	end,

	addUndo = function(entry)
		local last = undo.chain[#undo.chain]
		if last and last.action == entry.action and not last.saved then
			if last.action == 'deleteText' then
				if last.args[3] == entry.args[1] and
					 last.args[4] == entry.args[2] then
					last.args = {
						last.args[1], last.args[2], entry.args[3], entry.args[4],
						last.args[5] .. entry.args[5]
					}
				else
					table.insert(undo.chain, entry)
				end
			else
				-- insertText (need to finish)
				table.insert(undo.chain, entry)
			end
		else
			table.insert(undo.chain, entry)
		end
	end,

	autocomplete = function()
		if lastAction ~= 'autocomplete' or not complete.results then
			local sLine = tLines[y]:sub(1, x - 1)
			local nStartPos = sLine:find("[a-zA-Z0-9_%.]+$")
			if nStartPos then
				sLine = sLine:sub(nStartPos)
			end
			if #sLine > 0 then
				complete.results = textutils.complete(sLine)
			else
				complete.results = { }
			end
			complete.index = 0
			complete.x = x
		end

		if #complete.results == 0 then
			setError('No completions available')

		elseif #complete.results == 1 then
			actions.insertText(x, y, complete.results[1])
			complete.results = nil

		elseif #complete.results > 1 then
			local prefix = complete.results[1]
			for n = 1, #complete.results do
				local result = complete.results[n]
				while #prefix > 0 do
					if result:find(prefix, 1, true) == 1 then
						break
					end
					prefix = prefix:sub(1, #prefix - 1)
				end
			end
			if #prefix > 0 then
				actions.insertText(x, y, prefix)
				complete.results = nil
			else
				if complete.index > 0 then
					actions.deleteText(complete.x, y, complete.x + #complete.results[complete.index], y)
				end
				complete.index = complete.index + 1
				if complete.index > #complete.results then
					complete.index = 1
				end
				actions.insertText(complete.x, y, complete.results[complete.index])
			end
		end
	end,

	refresh = function()
		actions.dirty_all()
		mark.continue = mark.active
		setStatus('refreshed')
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
			local nx = tLines[ny]:lower():find(pattern, sx)
			if nx then
				if ny < y or ny == y and nx <= x then
					setStatus(messages.wrapped)
				end
				actions.go_to(nx, ny)
				actions.mark_to(nx + #pattern, ny)
				actions.go_to(nx, ny)
				return
			end
			sx = 1
		end
		setError('Pattern not found')
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

	save = function(filename)
		filename = filename or fileInfo.abspath
		if fs.isReadOnly(filename) then
			setError("Access denied")
		else
			local ok = save(filename)
			if ok then
				lastSave = undo.chain[#undo.chain]
				fileInfo = getFileInfo(filename)
				if multishell then
					multishell.setTitle(multishell.getCurrent(), fileInfo.path)
				end
				setStatus('"%s" %dL, %dC written',
					 fileInfo.path, #tLines, fs.getSize(fileInfo.abspath))
					 return true
			else
				setError("Error saving to %s", filename)
			end
		end
	end,

	save_as = function()
		page.save_as:show()
	end,

	exit = function()
		if undo.chain[#undo.chain] ~= lastSave then
			page.quit:show()
		else
			UI:quit()
		end
	end,

	run = function()
		--input:reset()
		local sTempPath = "/.temp"
		local ok = save(sTempPath)
		if ok then
			local nTask = shell.openTab(sTempPath)
			if nTask then
				shell.switchTab(nTask)
			else
				setError("Error starting Task")
			end
			os.sleep(0)
			fs.delete(sTempPath)
		else
			setError("Error saving to %s", sTempPath)
		end
	end,

	status = function()
		local modified = ''
		if undo.chain[1] then
			modified = '[Modified] '
		end
		setStatus('"%s" %s%d lines --%d%%--',
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

	setCursor = function()
		lastPos.x = x
		lastPos.y = y

		local screenX = x - scrollX
		local screenY = y - scrollY

		if screenX < 1 then
			scrollX = x - 1
			actions.dirty_all()
		elseif screenX > w then
			scrollX = x - w
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

	pageUp = function()
		actions.go_to(x, y - h)
	end,

	pageDown = function()
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
			local lines = split(text)
			local remainder = sLine:sub(x)
			tLines[y] = sLine:sub(1, x - 1) .. lines[1]
			actions.dirty_range(y, #tLines + #lines)
			x = x + #lines[1]
			for k = 2, #lines do
				y = y + 1
				table.insert(tLines, y, lines[k])
				x = #lines[k] + 1
			end
			tLines[y] = tLines[y]:sub(1, x) .. remainder
		end

		if not undo.active then
			actions.addUndo(
				{ action = 'deleteText', args = { sx, sy, x, y, text } })
		end
	end,

	deleteText = function(sx, sy, ex, ey)
		x = sx
		y = sy

		if not undo.active then
			local text = actions.copyText(sx, sy, ex, ey)
			actions.addUndo(
				{ action = 'insertText', args = { sx, sy, text } })
		end

		local front = tLines[sy]:sub(1, sx - 1)
		local back = tLines[ey]:sub(ex, #tLines[ey])
		for _ = 2, ey - sy + 1 do
			table.remove(tLines, y + 1)
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
				table.insert(lines, str)
			end
		end
		return table.concat(lines, '\n'), count
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
		if mark.active then
			actions.delete()
		elseif actions.left() then
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
		actions.insertText(x, y, '\n' .. string.rep(' ', spaces))
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
		setStatus('shift-^v to paste')
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
			setStatus('%d chars added', #text)
		else
			setStatus('Clipboard empty')
		end
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

	process = function(action, param, param2)
		if not actions[action] then
			error('Invaid action: ' .. action)
		end

		local wasMarking = mark.continue
		mark.continue = false

		actions[action](param, param2)
		lastAction = action

		if x ~= lastPos.x or y ~= lastPos.y then
			actions.setCursor()
		end
		if not mark.continue and wasMarking then
			actions.unmark()
		end

		actions.redraw()
	end,
}

local tArgs = { ... }
if #tArgs == 0 then
	error( "Usage: edit <path>" )
end

-- Error checking
local sPath = shell.resolve(tArgs[1])
if fs.exists(sPath) and fs.isDir(sPath) then
	error( "Cannot edit a directory." )
end

load(tArgs[1])

if multishell then
	multishell.setTitle(multishell.getCurrent(), fs.getName(sPath))
end

UI:setPage(page)
UI:start()

