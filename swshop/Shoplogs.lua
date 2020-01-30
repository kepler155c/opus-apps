local UI     = require('opus.ui')
local Util   = require('opus.util')
local Event  = require('opus.event')
local Config = require('opus.config')

local colors = _G.colors
local fs     = _G.fs

UI:configure('Shoplogs', ...)

local args = Util.parse( ... )
local logFile = args[1] or '/usr/swshop.log'

local config = Config.load('Shoplogs', {
	timezone = 0,
})

local page = UI.Page {
	notification = UI.Notification {},
	accelerators = { ['control-r'] = 'reload' },

	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Reload', event = 'reload' },
			{
				x = -3,
				text = '\187',
				dropdown = {
					{ text = 'Purge Logs', event = 'purge' },
					{ text = 'Set timezone', event = 'set_timezone' },
				},
			},
		}
	},

	grid = UI.ScrollingGrid {
		y = 2,
		autospace = true,
		inverseSort = true, -- ?
		sortColumn = 'time',
		columns = {
			{ heading = 'Buyer', key = 'from' },
			{ heading = 'Item', key = 'id' },
			{ heading = 'Paid', key = 'value' },
			{ heading = 'Purc', key = 'purchased' },
		},
	},

	tzSlide = UI.Dialog {
		title = 'Set timezone',
		y = -4,
		form = UI.Form {
			x = 3, y = 3,
			event = 'set_tz',
			cancelEvent = 'slide_hide',
			values = config,
			chooser = UI.Chooser {
				formLabel = 'UTC',
				formKey = 'timezone',
				width = 7,
				nochoice = config.timezone,
			},
		},
	},

	txSlide = UI.SlideOut {
		titleBar = UI.TitleBar { title = 'Transaction Information',	event = 'tx_close' },
		accelerators = { ['backspace'] = 'tx_close' },
		grid = UI.ScrollingGrid {
			y = 2,
			disableHeader = true,
			autospace = true,
			columns = {
				{ key = 'name', textColor = colors.yellow },
				{ key = 'value' },
			}
		},
	},
}
page:setFocus(page.grid)

function page.tzSlide.form.chooser:enable()
	for i = -12, 12 do
		table.insert(self.choices, {
			name = ('%#3d'):format(i),
			value = i,
		})
	end

	UI.Chooser.enable(self)
end

function page.txSlide:show(data)
	local t = {}
	for k,v in pairs(data) do
		table.insert(t, {name = k, value = v})
	end
	self.grid:setValues(t)

	UI.SlideOut.show(self)
end

function page.menuBar:eventHandler(event)
	if event.type == "purge" then
		page.grid.values = {}
		page.grid:update()
		page.grid:draw()
		fs.delete(logFile)

	elseif event.type == "set_timezone" then
		page.tzSlide:show()

	else
		return UI.MenuBar.eventHandler(self, event)
	end
	return true
end

function page.txSlide:eventHandler(event)
	if event.type == 'tx_close' then
		self:hide()
		page:setFocus(page.grid)
	else
		return UI.SlideOut.eventHandler(self, event)
	end
	return true
end

function page.grid:getRowTextColor(row, selected)
	return row.reason and colors.orange or UI.ScrollingGrid.getRowTextColor(self, row, selected)
end

function page.txSlide.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	if row.name == 'time' then
		row.value = os.date('!%c', row.value+(3600*config.timezone))
	end
	return row
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	local x = row.recipient
	row.from = x and x:match('(.+)@') or row.from
	return row
end

function page.grid:addTransaction(transaction)
	table.insert(self.values, transaction)
	self:update()
end

function page.grid:loadTransactions()
	local logs = Util.readTable(logFile) or {}
	self:setValues(logs)
	self:update()
end

function page:eventHandler(event)
	if event.type == "grid_select" then
		self.txSlide:show(event.selected)

	elseif event.type == 'set_tz' then
		Config.update('Shoplogs', config)
		self.notification:success('Timezone updated')
		self.tzSlide:hide()

	elseif event.type == 'tz_close' then
		self.tzSlide:hide()
		page:setFocus(page.grid)

	elseif event.type == 'reload' then
		self.grid:loadTransactions()
		self.notification:success('Logs reloaded!')
		self.grid:update()
		self.grid:draw()

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

Event.on('shop_transaction', function(_, tx)
	page.grid:addTransaction(tx)
	page.grid:draw()
	page.grid:sync()
end)

page.grid:loadTransactions()
UI:setPage(page)
UI:pullEvents()
