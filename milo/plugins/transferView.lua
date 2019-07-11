local Milo       = require('milo')
local Tasks      = require('milo.taskRunner')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local colors     = _G.colors
local device     = _G.device

local context    = Milo:getContext()

--[[ Configuration Screen ]]
local wizardPage = UI.WizardPage {
	title = 'Transfer Inventory',
	index = 2,
	backgroundColor = colors.cyan,
	grid = UI.ScrollingGrid {
		y = 2, ey = -2,
		values = context.storage.nodes,
		columns = {
			{                   key = 'suffix',     width = 4, align = 'right' },
			{ heading = 'Name', key = 'displayName' },
			{ heading = 'Type', key = 'mtype',      width = 4 },
			{ heading = 'Pri',  key = 'priority',   width = 3 },
		},
		sortColumn = 'displayName',
		help = 'Double-click to set target',
	},
}

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.pullItems and {
		name = 'Transfer',
		value = 'xfer',
		category = 'custom',
		help = 'Transfer contents',
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'xfer'
end

function wizardPage:setNode(node)
	self.node = node

	local t = Util.filter(context.storage.nodes, function(v)
		return v.mtype ~= 'ignore' and device[v.name] and v.mtype ~= 'hidden'
	end)

	self.grid:setValues(t)
end

function wizardPage.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	local t = { row.name:match(':(.+)_(%d+)$') }
	if #t ~= 2 then
		t = { row.name:match('(.+)_(%d+)$') }
	end
	if t and #t == 2 then
		row.name, row.suffix = table.unpack(t)
		row.name = row.name .. '_' .. row.suffix
	end
	row.displayName = row.displayName or row.name
	return row
end

function wizardPage.grid:getRowTextColor(row, selected)
	if row.name == self.parent.node.target then
		return colors.yellow
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function wizardPage:eventHandler(event)
	if event.type == 'grid_select' then
		self.node.target = event.selected.name
		self.grid:draw()
	end
	return UI.Page.eventHandler(self, event)
end

UI:getPage('nodeWizard').wizard:add({ transferChest = wizardPage })

local function transfer(node)
	local tasks = Tasks({
		errorMsg = 'TRANSFER error: '
	})

	local target = context.storage.nodes[node.target]
	if not target or not target.adapter or not target.adapter.online then
		error(string.format('TRANSFER: target %s is not online', node.name))
	end

	if target.mtype == 'storage' then
		context.storage.dirty = true
		target.adapter.dirty = true
	end

	for k in pairs(node.adapter.list()) do
		tasks:add(function()
			node.adapter.pushItems(node.target, k)
		end)
	end

	function tasks:onError(msg)
		_G._syslog('TRANSFER error: ' .. msg)
	end
	tasks:run()
end

--[[ Task ]]--
local Task = {
	name = 'transfer',
	priority = 99,
}

function Task:cycle()
	for node in context.storage:filterActive('xfer') do
		local s, m = pcall(transfer, node)
		if not s and m then
			_G._syslog('TRANSFER error:' .. m)
		end
	end
end

Milo:registerTask(Task)
