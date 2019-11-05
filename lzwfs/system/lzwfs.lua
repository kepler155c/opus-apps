local Config = require('opus.config')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local fs = _G.fs

local config = Config.load('lzwfs', {
	enabled = false,
	filters = {
		'packages/',
		'sys/',
		'usr/config/',
	}
})

local tab = UI.Tab {
	tabTitle = 'Compression',
	description = 'Disk compression',
	label1 = UI.Text {
		x = 2, y = 2,
		value = 'Enable compression',
	},
	checkbox = UI.Checkbox {
		x = 20, y = 2,
		value = config.enabled
	},
	entry = UI.TextEntry {
		x = 2, y = 4, ex = -2,
		limit = 256,
		shadowText = 'enter new path',
		accelerators = {
			enter = 'add_path',
		},
		help = 'add a new path',
	},
	grid = UI.Grid {
		x = 2, ex = -2, y = 6, ey = -5,
		disableHeader = true,
		columns = { { key = 'value' } },
		autospace = true,
		sortColumn = 'index',
		help = 'double-click to remove',
		accelerators = {
			delete = 'remove',
		},
	},
	button = UI.Button {
		x = -9, ex = -2, y = -3,
		text = 'Apply',
		event = 'apply',
	},
	statusBar = UI.StatusBar { },
}

function tab:enable()
	self.grid.values = { }
	for k,v in ipairs(config.filters or { }) do
		table.insert(self.grid.values, { index = k, value = v })
	end
	self.grid:update()
	UI.Tab.enable(self)
end

local function rewriteFiles(p)
	if type(p) == 'table' then
		for _, path in pairs(p) do
			rewriteFiles(path)
		end
	else
		local function recurse(path)
			_G._syslog('rewriting: ' .. path)
			if fs.isDir(path) then
				for _, v in pairs(fs.listEx(path)) do
					if not v.isReadOnly then
						recurse(fs.combine(path, v.name))
					end
				end
			else
				local c = Util.readFile(path)
				Util.writeFile(path, c)
			end
		end

		recurse(fs.combine(p, ''))
	end
end

function tab:eventHandler(event)
	if event.type == 'add_path' then
		table.insert(self.grid.values, {
			index = #self.grid.values + 1,
			value = self.entry.value,
		})
		self.entry:reset()
		self.entry:draw()
		self.grid:update()
		self.grid:draw()
		return true

	elseif event.type == 'grid_select' or event.type == 'remove' then
		local selected = self.grid:getSelected()
		if selected then
			table.remove(self.grid.values, selected.index)
			self.grid:update()
			self.grid:draw()
		end

	elseif event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help)

	elseif event.type == 'apply' then
		local filters = { }

		for _, v in pairs(self.grid.values) do
			table.insert(filters, v.value)
		end

		if self.checkbox.value ~= config.enabled then
			if not self.checkbox.value then
				fs.option('compression', 'filters', { })
				rewriteFiles(config.filters)
				fs.option('compression', 'enabled', false)
			else
				fs.option('compression', 'enabled', true)
				fs.option('compression', 'filters', filters)
				rewriteFiles(filters)
			end
		elseif self.checkbox.value then
			fs.option('compression', 'filters', filters)
			for _,v in pairs(filters) do
				if not Util.find(config.filters, v) then
					rewriteFiles(v) -- uncompress paths not in current filter
				end
			end

			for _,v in pairs(config.filters) do
				if not Util.find(filters, v) then
					rewriteFiles(v) -- compress new filters
				end
			end
		end
		config.filters = filters
		config.enabled = self.checkbox.value
		Config.update('lzwfs', config)

		self:emit({ type = 'success_message', message = 'Settings updated' })
	end

	return UI.Tab.eventHandler(self, event)
end

return tab
