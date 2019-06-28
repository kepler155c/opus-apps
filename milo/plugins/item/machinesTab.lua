local Craft   = require('milo.craft2')
local Milo    = require('milo')
local UI      = require('opus.ui')
local Util    = require('opus.util')

local colors  = _G.colors
local context = Milo:getContext()

local machinesTab = UI.Tab {
	tabTitle = 'Machine',
	index = 3,
	backgroundColor = colors.cyan,
	grid = UI.ScrollingGrid {
		x = 2, ex = -2, y = 2, ey = -2,
		disableHeader = true,
		columns = {
			{ heading = 'Name', key = 'displayName'},
		},
		sortColumn = 'displayName',
		help = 'Double-click to set machine',
	},
}

function machinesTab:setItem(item)
	self.item = item
	local machine = Craft.machineLookup[self.item.key]
	local t = Util.filter(context.storage.nodes, function(node)
		if node.category == 'machine' or node.category == 'custom' then -- TODO: - need a setting instead (ie. canCraft)
			return node.adapter and node.adapter.online and node.adapter.pushItems
		end
	end)
	self.grid:setValues(t)
	if machine then
		self.grid:setSelected('name', machine)
	end
	self.parent:setActive(self, item.has_recipe)
end

function machinesTab.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = row.displayName or row.name
	return row
end

function machinesTab.grid:getRowTextColor(row, selected)
	if row.name == Craft.machineLookup[self.parent.item.key] then
		return colors.yellow
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function machinesTab:eventHandler(event)
	if event.type == 'grid_select' then
		if event.selected.name == Craft.machineLookup[self.item.key] then
			Craft.machineLookup[self.item.key] = nil
		else
			Craft.machineLookup[self.item.key] = event.selected.name
		end
		Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)

		self.grid:draw()
		self:emit({ type = 'info_message', message = 'Saved' })

		return true
	end
end

return { itemTab = machinesTab }
