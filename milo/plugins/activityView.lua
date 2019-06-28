local Ansi       = require('opus.ansi')
local Event      = require('opus.event')
local Milo       = require('milo')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local colors     = _G.colors
local context    = Milo:getContext()
local device     = _G.device
local os         = _G.os

--[[ Configuration Page ]]--
local template =
[[%sDisplays the amount of items entering or leaving storage.%s
Right-clicking on the activity monitor will reset the totals.]]

local wizardPage = UI.WizardPage {
	title = 'Activity Monitor',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = 6,
		marginRight = 0,
		value = string.format(template, Ansi.yellow, Ansi.reset),
	},
	form = UI.Form {
		x = 2, ex = -2, y = 7, ey = -2,
		manualControls = true,
		[1] = UI.Chooser {
			width = 9,
			formLabel = 'Font Size', formKey = 'textScale',
			nochoice = 'Small',
			choices = {
				{ name = 'Small', value = .5 },
				{ name = 'Large', value = 1  },
			},
			help = 'Adjust text scaling',
		},
	},
}

function wizardPage:setNode(node)
	self.form:setValues(node)
end

function wizardPage:validate()
	return self.form:save()
end

function wizardPage:saveNode(node)
	os.queueEvent('monitor_resize', node.name)
end

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'monitor' and {
		name = 'Activity Monitor',
		value = 'activity',
		category = 'display',
		help = 'Display storage activity'
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'activity'
end

UI:getPage('nodeWizard').wizard:add({ activity = wizardPage })

--[[ Display ]]--
local function createPage(node)
	local monitor = UI.Device {
		device = node.adapter,
		textScale = node.textScale or .5,
	}

	function monitor:resize()
		self.textScale = node.textScale or .5
		UI.Device.resize(self)
	end

	local page = UI.Page {
		parent = monitor,
		backgroundColor = colors.black,
		grid = UI.Grid {
			ey = -3,
			columns = {
				{ heading = 'Qty',  key = 'count',      width = 6, align = 'right' },
				{ heading = '+/-',  key = 'change',     width = 6, align = 'right' },
				{ heading = 'Name', key = 'displayName' },
				{ heading = 'Rate', key = 'rate',       width = 6, align = 'right' },
			},
			sortColumn = 'displayName',
			headerBackgroundColor = colors.black,
			headerTextColor = colors.cyan,
			headerHeight = 2,
		},
		buttons = UI.Window {
			y = -1,
			backgroundColor = colors.black,
			prevButton = UI.Button {
				x = 1, width = 5,
				event = 'previous',
				textColor = colors.cyan,
				backgroundColor = colors.black,
				text = ' < '
			},
			resetButton = UI.Button {
				x = 7, ex = -7,
				event = 'reset',
				textColor = colors.cyan,
				backgroundColor = colors.black,
				text = 'Reset'
			},
			nextButton = UI.Button {
				x = -5, width = 5,
				event = 'next',
				textColor = colors.cyan,
				backgroundColor = colors.black,
				text = ' > '
			},
		},
		timestamp = os.clock(),
	}

	function page.grid:getRowTextColor(row, selected)
		if row.lastCount and row.lastCount ~= row.count then
			return row.count > row.lastCount and colors.yellow or colors.lightGray
		end
		return UI.Grid:getRowTextColor(row, selected)
	end

	function page.grid:getDisplayValues(row)
		row = Util.shallowCopy(row)

		local ind = '+'
		if row.change < 0 then
			ind = ''
		end

		row.change = ind .. Util.toBytes(row.change)
		row.count = Util.toBytes(row.count)
		row.rate = Util.toBytes(row.rate)

		return row
	end

	function page:eventHandler(event)
		if event.type == 'reset' then
			self:reset()

		elseif event.type == 'next' then
			self.grid:nextPage()

		elseif event.type == 'previous' then
			self.grid:previousPage()

		else
			return UI.Page.eventHandler(self, event)
		end

		Event.onTimeout(.1, function()
			self:setFocus(self.grid)
			self:sync()
		end)
		return true
	end

	function page:reset()
		self.lastItems = nil
		self.grid:setValues({ })
		self.grid:draw()
	end

	function page:refresh()
		local t = context.storage.cache

		if t and not self.lastItems then
			self.lastItems = { }
			for k,v in pairs(t) do
				self.lastItems[k] = {
					displayName = v.displayName,
					initialCount = v.count,
				}
			end
			self.timestamp = os.clock()
			self.grid:setValues({ })

		else
			for _,v in pairs(self.lastItems) do
				v.lastCount = v.count
				v.count = nil
			end

			self.elapsed = os.clock() - self.timestamp

			for k,v in pairs(t) do
				local v2 = self.lastItems[k]
				if v2 then
					v2.count = v.count
				else
					self.lastItems[k] = {
						displayName = v.displayName,
						count = v.count,
						initialCount = 0,
					}
				end
			end

			local changedItems = { }
			for k,v in pairs(self.lastItems) do
				if not v.count then
					v.count = 0
				end
				if v.count ~= v.initialCount then
					v.change  = v.count - v.initialCount
					v.rate = Util.round(60 / self.elapsed * v.change, 1)
					changedItems[k] = v
				end
			end

			self.grid:setValues(changedItems)
		end
		self.grid:draw()
	end

	function page:update()
		page:refresh()
		page:sync()
	end

	UI:setPage(page)
	return page
end

local pages = { }

--[[ Task ]]--
local ActivityTask = {
	name = 'activity',
	priority = 30,
}

function ActivityTask:cycle()
	for node in context.storage:filterActive('activity') do
		if not pages[node.name] then
			pages[node.name] = createPage(node)
		end
		pages[node.name]:update()
	end
end

Milo:registerTask(ActivityTask)
