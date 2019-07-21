local Ansi       = require('opus.ansi')
local Event      = require('opus.event')
local Milo       = require('milo')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local colors     = _G.colors
local context    = Milo:getContext()
local device     = _G.device
local os         = _G.os
local term       = _G.term

--[[ Configuration Page ]]--
local template =
[[%sDisplays the amount of items entering or leaving storage.%s
Right-clicking on the activity monitor will reset the totals.]]

local wizardPage = UI.WizardPage {
	title = 'Status Monitor',
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
		name = 'Status Monitor',
		value = 'status',
		category = 'display',
		help = 'Display storage status'
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'status'
end

UI:getPage('nodeWizard').wizard:add({ statusMonitor = wizardPage })

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
		tabs = UI.Tabs {
			[1] = UI.Tab {
				tabTitle = 'Overview',
				backgroundColor = colors.black,
				onlineLabel = UI.Text {
					x = 2, y = 2,
					value = 'Storage Status',
				},
				onlineText = UI.Text {
					x = 18, y = 2,
					width = 8,
				},
				tpsLabel = UI.Text {
					x = 2, y = 3,
					value = 'Tasks/sec',
				},
				tpsText = UI.Text {
					x = 18, y = 3,
					width = 8,
				},
				tasksLabel = UI.Text {
					x = -18, y = 3,
					value = 'Proc time',
				},
				tasksText = UI.Text {
					x = -6, ex = -2, y = 3,
					align = 'right',
				},
				storageLabel = UI.Text {
					x = 2, ex = -1, y = 6,
				},
				storage = UI.ProgressBar {
					x = 2, ex = -2, y = 7, height = 3,
					progressChar = ' ',
				},
				unlockedLabel = UI.Text {
					x = 2, ex = -1, y = 12,
				},
				unlocked = UI.ProgressBar {
					x = 2, ex = -2, y = 13, height = 3,
					progressChar = ' ',
				},
				craftingLabel = UI.Text {
					x = 2, ex = -1, y = 18,
					value = 'Crafting Status',
				},
				crafting = UI.ProgressBar {
					x = 2, ex = -2, y = 19, height = 3,
					progressChar = ' ',
					value = 100,
				},
			},
			[2] = UI.Tab {
				tabTitle = 'Stats',
				textArea = UI.TextArea {
					y = 3,
				},
			},
			[3] = UI.Tab {
				tabTitle = 'Storage',
				grid = UI.ScrollingGrid {
					y = 2,
					columns = {
						{ heading = 'Name', key = 'name' },
						{ heading = 'Size', key = 'size', width = 5 },
						{ heading = 'Used', key = 'used', width = 5 },
						{ heading = 'Perc', key = 'perc', width = 5 },
						-- TODO: add % to each number
					},
					sortColumn = 'name',
				},
			},
			[4] = UI.Tab {
				tabTitle = 'Offline',
				grid = UI.ScrollingGrid {
					y = 2,
					columns = {
						{ heading = 'Name', key = 'name' },
					},
					sortColumn = 'name',
				},
			},
			[5] = UI.Tab {
				tabTitle = 'Activity',
				term = UI.Embedded {
					--visible = true,
				},
			},
			[6] = UI.Tab {
				tabTitle = 'Tasks',
				grid = UI.ScrollingGrid {
					y = 2,
					values = context.tasks,
					columns = {
						{ heading = 'Priority', key = 'priority', width = 5 },
						{ heading = 'Name', key = 'name' },
						{ heading = 'Avg', key = 'avg', width = 7, align = 'right' },
						{ heading = '%', key = 'perc', width = 7, align = 'right' },
					},
					sortColumn = 'priority',
				},
			},
		},
	}

	local overviewTab = page.tabs[1]
	local statsTab = page.tabs[2]
	local usageTab = page.tabs[3]
	local stateTab = page.tabs[4]
	local activityTab = page.tabs[5]
	local taskTab = page.tabs[6]

	local function getStorageStats()
		local stats = { }
		local totals = {
			usedSlots = 0,
			totalSlots = 0,
			totalChests = 0,
			unlockedSlots = 0,
			usedUnlockedSlots = 0,
		}

		for n in context.storage:filterActive('storage') do
			if n.adapter.size and n.adapter.list then
				pcall(function()
					local updated = n.adapter.__lastUpdate ~= n.adapter.lastUpdate
					if updated then
						n.adapter.__used = Util.size(n.adapter.list())
						n.adapter.__lastUpdate = n.adapter.lastUpdate
					end
					if not n.adapter.__used then
						n.adapter.__used = Util.size(n.adapter.list())
					end
					table.insert(stats, {
						name = n.displayName or n.name,
						size = n.adapter.__size,
						used = n.adapter.__used,
						perc = math.floor(n.adapter.__used / n.adapter.__size * 100),
						updated = updated,
					})
					totals.usedSlots = totals.usedSlots + n.adapter.__used
					totals.totalSlots = totals.totalSlots + n.adapter.__size
					totals.totalChests = totals.totalChests + 1
					if not n.lock then
						totals.unlockedSlots = totals.unlockedSlots + n.adapter.__size
						totals.usedUnlockedSlots = totals.usedUnlockedSlots + n.adapter.__used
					end
				end)
			end
		end

		return stats, totals
	end

	function stateTab:refresh()
		self.grid.values = { }
		for _, v in pairs(context.storage.nodes) do
			if v.mtype ~= 'hidden' then
				if not v.adapter or not v.adapter.online then
					table.insert(self.grid.values, {
						name = v.displayName or v.name
					})
				end
			end
		end
		self.grid:update()
	end

	function stateTab:enable()
		self:refresh()
		self.handle = Event.onInterval(5, function()
			self:refresh()
			self.grid:draw()
			self:sync()
		end)
		UI.Tab.enable(self)
	end

	function stateTab:disable()
		Event.off(self.handle)
		UI.Tab.disable(self)
	end

	function usageTab:refresh()
		self.grid:setValues(getStorageStats())
	end

	function usageTab:enable()
		self:refresh()
		self.handle = Event.onInterval(5, function()
			self:refresh()
			self.grid:draw()
			self:sync()
		end)
		UI.Tab.enable(self)
	end

	function usageTab:disable()
		Event.off(self.handle)
		UI.Tab.disable(self)
	end

	function usageTab.grid:getRowTextColor(row, selected)
		return row.updated and colors.yellow or
			UI.Grid:getRowTextColor(row, selected)
	end

	function statsTab.textArea:draw()
		local _, stats = getStorageStats()
		local totalItems, nodeCount = 0, 0
		local formatString = [[
Storage Usage  : %d%%
Slots          : %d of %d used
Unique Items   : %d
Total Items    : %d
Nodes          : %d

Unlocked Slots : %d of %d (%d%%)
]]

		for _,v in pairs(context.storage.nodes) do
			if v.adapter and v.adapter.online then
				nodeCount = nodeCount + 1
			end
		end

		for _,v in pairs(context.storage.cache) do
			totalItems = totalItems + v.count
		end

		self.value = string.format(formatString,
			math.floor(stats.usedSlots / stats.totalSlots * 100),
			stats.usedSlots,
			stats.totalSlots,
			Util.size(context.storage.cache),
			totalItems,
			nodeCount,
			stats.usedUnlockedSlots,
			stats.unlockedSlots,
			math.floor(stats.usedUnlockedSlots / stats.unlockedSlots * 100))
		UI.TextArea.draw(self)
	end

	function statsTab:enable()
		self.handle = Event.onInterval(5, function()
			self.textArea:draw()
			self:sync()
		end)
		UI.Tab.enable(self)
	end

	function statsTab:disable()
		Event.off(self.handle)
		UI.Tab.disable(self)
	end

	function taskTab.grid:getDisplayValues(row)
		return {
			name = row.name,
			priority = row.priority,
			avg  = Util.round(row.execTime / context.taskCounter * 1000) .. ' ms',
			perc = Util.round(row.execTime / context.taskTimer * 100) .. '%',
		}
	end

	function taskTab:refresh()
		self.grid:update()
	end

	function taskTab:enable()
		self:refresh()
		self.handle = Event.onInterval(5, function()
			self:refresh()
			self.grid:draw()
			self:sync()
		end)
		UI.Tab.enable(self)
	end

	function taskTab:disable()
		Event.off(self.handle)
		UI.Tab.disable(self)
	end

	function overviewTab:draw()
		local _, stats = getStorageStats()

		self.onlineText.textColor = context.storage:isOnline() and colors.green or colors.red
		self.onlineText.value = context.storage:isOnline() and 'Online' or 'Offline'

		self.tpsText.value = tostring(Util.round(self.tasks / (os.clock() - self.timer), 2))
		self.tasksText.value = tostring(Util.round(context.taskTimer / context.taskCounter, 2))

		local total, crafted = 0, 0
		for _,v in pairs(context.craftingQueue) do
			total = total + v.requested
			crafted = crafted + v.crafted
		end
		if Milo:isCraftingPaused() then
			self.crafting.progressColor = colors.yellow
			self.crafting.value = 100
		else
			self.crafting.progressColor = colors.orange
			self.crafting.value = total > 0 and math.ceil(crafted / total * 100) or 0
		end

		local percent = math.floor(stats.usedSlots / stats.totalSlots * 100)
		local color = colors.green
		if percent > 90 then
			color = colors.red
		elseif percent > 75 then
			color = colors.yellow
		end
		self.storage.progressColor = color
		self.storage.value = percent

		self.storageLabel.value = string.format('Total Usage: %s%% (%s of %s slots)',
			percent, stats.usedSlots, stats.totalSlots)

		percent = math.floor(stats.usedUnlockedSlots / stats.unlockedSlots * 100)
		color = colors.green
		if percent > 90 then
			color = colors.red
		elseif percent > 75 then
			color = colors.yellow
		end
		self.unlocked.progressColor = color
		self.unlocked.value = percent

		self.unlockedLabel.value = string.format('Unlocked Usage: %s%% (%s of %s slots)',
			percent, stats.usedUnlockedSlots, stats.unlockedSlots)

		UI.Tab.draw(self)
	end

	function overviewTab:enable()
		self.timer = os.clock()
		self.tasks = 0
		self.handle = Event.onInterval(5, function()
			self:draw()
			self:sync()
		end)
		self.handle2 = Event.on({ 'milo_resume', 'milo_pause', 'storage_offline', 'storage_online' }, function()
			self:draw()
			self:sync()
		end)
		self.handle3 = Event.on({ 'plethora_task', 'task_complete' }, function()
			self.tasks = self.tasks + 1
		end)
		UI.Tab.enable(self)
	end

	function overviewTab:disable()
		Event.off(self.handle)
		Event.off(self.handle2)
		Event.off(self.handle3)
		UI.Tab.disable(self)
	end

	function page:eventHandler(event)
		if event.type == 'tab_activate' then
			local state = Milo:getState('statusState') or { }
			state[node.name] = event.activated.tabTitle
			Milo:setState('statusState', state)
		end
		return UI.Page.eventHandler(self, event)
	end

	table.insert(context.loggers, function(...)
		local oterm = term.redirect(activityTab.term.win)
		activityTab.term.win.scrollBottom()
		Util.print(...)
		term.redirect(oterm)
		if activityTab.enabled then
			activityTab:sync()
		end
	end)

	Event.onTimeout(0, function()
		UI:setPage(page)
	end)

	-- restore active tab
	local tabState = Milo:getState('statusState') or { }
	if tabState[node.name] then
		page.tabs:selectTab(Util.find(page.tabs, 'tabTitle', tabState[node.name]))
	end

	return page
end

local pages = { }

--[[ Task ]]--
local task = {
	name = 'status',
	priority = 99,
}

function task:cycle()
	for node in context.storage:filterActive('status') do
		if not pages[node.name] then
			pages[node.name] = createPage(node)
		end
	end
end

Milo:registerTask(task)
