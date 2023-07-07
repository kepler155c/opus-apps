local itemDB = require('core.itemDB')
local Event  = require('opus.event')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local args       = { ... }
local colors     = _G.colors
local peripheral = _G.peripheral

local ni = peripheral.find('neuralInterface')
local context = args[1]

if not context.state.autostore then
	context.state.autostore = { }
end

local page = UI.Page {
	titleBar = UI.TitleBar {
		backgroundColor = colors.gray,
		title = 'Auto deposit items',
		previousPage = true,
	},
	tabs = UI.Tabs {
		y = 2, ey = -2,
		inventory = UI.Tab {
			title = 'Inventory',
			grid = UI.ScrollingGrid {
				y = 2, ey = -2,
				columns = {
					{ heading = 'Name', key = 'displayName' },
				},
				sortColumn = 'displayName',
			},
		},
		autostore = UI.Tab {
			title = 'Deposit',
			grid = UI.ScrollingGrid {
				y = 2, ey = -2,
				columns = {
					{ heading = 'Name', key = 'displayName' },
				},
				sortColumn = 'displayName',
			},
		},
	},
	statusBar = UI.StatusBar {
		values = 'Double-click to toggle auto-deposit'
	},
}

local function makeKey(item)
	local damage = item.maxDamage == 0 and item.damage
	return itemDB:makeKey({ name = item.name, damage = damage })
end

function page.tabs.inventory:enable()
	local inv = ni.getInventory().list()
	local list = { }

	for k, item in pairs(inv) do
		item = itemDB:get(item, function() return ni.getInventory().getItemDetail(k) end)
		local key = makeKey(item)
		if not list[key] then
			item.key = key
			item.displayName = item.displayName:match('(.+) %(damage:.+%)') or item.displayName
			list[key] = item
		end
	end

	self.grid:setValues(list)
	itemDB:flush()

	return UI.Tab.enable(self)
end

function page.tabs.inventory.grid:getRowTextColor(row)
	if context.state.autostore[row.key] then
		return colors.yellow
	end
	return UI.ScrollingGrid.getRowTextColor(self, row)
end

function page.tabs.inventory:eventHandler(event)
	if event.type == 'grid_select' then
		local autostore = context.state.autostore or { }
		local key = makeKey(event.selected)
		if autostore[key] then
			autostore[key] = nil
		else
			autostore[key] = true
		end
		context:setState('autostore', autostore)
		self.grid:draw()
		return true
	end
end

function page.tabs.autostore:enable()
	local list = { }

	for key in pairs(context.state.autostore or { }) do
		local cItem = itemDB:get(key)
		if cItem then
			table.insert(list, cItem)
		end
	end
	self.grid:setValues(list)

	return UI.Tab.enable(self)
end

function page.tabs.autostore:eventHandler(event)
	if event.type == 'grid_select' then
		local key = makeKey(event.selected)
		context.state.autostore[key] = nil
		context:setState('autostore', context.state.autostore)
		Util.removeByValue(self.grid.values, event.selected)
		self.grid:update()
		self.grid:draw()
		return true
	end
end

Event.onInterval(5, function()
	if context.socket and
		 context.state.deposit and
		 (context.state.useShield or context.state.slot) and
		 not Util.empty(context.state.autostore) then

		pcall(function() -- prevent errors from some mod items
			for slot,v in pairs(ni.getInventory().list()) do
				local item = itemDB:get(v, function() ni.getInventory().getItemDetail(slot) end)
				if item then
					if context.state.autostore[makeKey(item)] then
						context:sendRequest({
							request = 'deposit',
							source = 'inventory',
							slot = slot,
							count = item.count,
						})
					end
				end
			end
		end)
	end
end)

return {
	menuItem = 'Auto-deposit',
	callback = function()
		UI:setPage(page)
	end,
}
