local Craft   = require('milo.craft2')
local Event   = require('opus.event')
local itemDB  = require('core.itemDB')
local Milo    = require('milo')
local Sound   = require('opus.sound')
local UI      = require('opus.ui')
local Util    = require('opus.util')

local colors  = _G.colors
local context = Milo:getContext()
local device  = _G.device
local os         = _G.os

--[[ Configuration Screen ]]
local wizardPage = UI.WizardPage {
	title = 'Crafting Monitor',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = 3,
		marginRight = 0,
		textColor = colors.yellow,
		value = 'Displays the crafting progress.'
	},
	form = UI.Form {
		x = 2, ex = -2, y = 4, ey = -2,
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

function wizardPage:saveNode(node)
	os.queueEvent('monitor_resize', node.name)
end

function wizardPage:validate()
	return self.form:save()
end

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'monitor' and {
		name = 'Crafting Monitor',
		value = 'jobs',
		category = 'display',
		help = 'Display crafting progress / jobs'
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'jobs'
end

UI:getPage('nodeWizard').wizard:add({ jobs = wizardPage })

--[[ Display ]]
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
		grid = UI.Grid {
			--ey = -6,
			sortColumn = 'index',
			columns = {
				{ heading = 'Qty',      key = 'remaining',   width = 4 },
				{ heading = 'Crafting', key = 'displayName', },
				{ heading = 'Status',   key = 'status',      },
	--			{ heading = 'need',   key = 'need',    width = 4  },
	--      { heading = 'total',   key = 'total',  width = 4    },
	--      { heading = 'used',   key = 'used',   width = 4   },
	--      { heading = 'count',   key = 'count', width = 4     },
	--			{ heading = 'crafted',   key = 'crafted',  width = 5    },
	--      { heading = 'Progress', key = 'progress',    width = 8 },
			},
			headerBackgroundColor = colors.black,
			headerTextColor = colors.cyan,
			headerHeight = 2,
		},
--[[
		buttons = UI.Window {
			y = -5, height = 5,
			backgroundColor = colors.gray,
			prevButton = UI.Button {
				x = 2, y = 2, height = 3, width = 5,
				event = 'previous',
				backgroundColor = colors.lightGray,
				text = ' < '
			},
			cancelButton = UI.Button {
				x = 8, y = 2, height = 3, ex = -8,
				event = 'cancel_job',
				backgroundColor = colors.lightGray,
				text = 'Cancel Job'
			},
			nextButton = UI.Button {
				x = -6, y = 2, height = 3, width = 5,
				event = 'next',
				backgroundColor = colors.lightGray,
				text = ' > '
			},
		},
]]
	}

	function page:updateList(craftList)
		if not Milo:isCraftingPaused() then
			local t = { }
			for _,v in pairs(craftList) do
				table.insert(t, v)
				v.index = #t
				for k2,v2 in pairs(v.ingredients or { }) do
					if v2.key ~= v.key --[[and v2.statusCode ]] then
						if v2.need > 0 or v2.statusCode then
							table.insert(t, v2)
							if not v2.displayName then
								v2.displayName = itemDB:getName(k2)
							end
							v2.index = #t
						end
					end
				end
			end
			self.grid:setValues(t)
			self.grid:update()
			self:draw()
			self:sync()
		end
	end

	function page.grid:getDisplayValues(row)
		row = Util.shallowCopy(row)
		if not row.displayName then
			row.displayName = itemDB:getName(row)
		end
		if row.requested then
			row.remaining = math.max(0, row.requested - row.crafted)
--_syslog('%d %d %d %d', row.remaining, row.requested, row.total, row.crafted)
			row.status = (row.status or '') ..
				string.format(' %d of %d', row.crafted + row.total, row.total + row.requested)
		else
			row.displayName = '  ' .. row.displayName
			row.status = (row.status or '') .. string.format(' %d of %d', row.count, row.total)
		end
		--row.progress = string.format('%d/%d', row.crafted, row.count)
		return row
	end

	function page.grid:getRowTextColor(row, selected)
		local statusColor = {
			[ Craft.STATUS_ERROR ] = colors.red,
			[ Craft.STATUS_WARNING ] = colors.orange,
			[ Craft.STATUS_INFO ] = colors.yellow,
			[ Craft.STATUS_SUCCESS ] = colors.green,
		}
		return row.statusCode and statusColor[row.statusCode] or
			UI.Grid:getRowTextColor(row, selected)
	end

	-- no sorting allowed
	function page:setInverseSort() end
	function page:setSortColumn() end

	function page:eventHandler(event)
		if event.type == 'cancel_job' then
			Sound.play('entity.villager.no', .5)

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

	UI:setPage(page)
	return page
end

local pages = { }

Event.on({ 'milo_resume', 'milo_pause' }, function(_, reason)
	for node in context.storage:filterActive('jobs') do
		local page = pages[node.name]
		if page then
			if reason then
				page.grid:clear()
				page.grid:centeredWrite(math.ceil(page.grid.height / 2), reason.msg)
			else
				page.grid:draw()
			end
			page:sync()
		end
	end
end)

--[[ Task ]]
local task = {
	name = 'job status',
	priority = 80,
}

function task:cycle()
	for node in context.storage:filterActive('jobs') do
		if not pages[node.name] then
			pages[node.name] = createPage(node)
		end
		pages[node.name]:updateList(context.craftingQueue)
	end
end

Milo:registerTask(task)
