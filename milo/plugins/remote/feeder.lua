local itemDB = require('core.itemDB')
local Event  = require('opus.event')
local Sound  = require('opus.sound')
local UI     = require('opus.ui')

local args       = { ... }
local colors     = _G.colors
local peripheral = _G.peripheral

local ni = peripheral.find('neuralInterface')
local context = args[1]

local page = UI.Page {
	titleBar = UI.TitleBar {
		backgroundColor = colors.gray,
		title = 'Auto-feeder',
		previousPage = true,
	},
	grid = UI.ScrollingGrid {
		y = 2, ey = -2,
		columns = {
			{ heading = 'Name', key = 'displayName' },
		},
		sortColumn = 'displayName',
	},
	statusBar = UI.StatusBar {
		values = 'Double-click to toggle'
	},
}

function page:enable()
	local inv = ni.getInventory().list()
	local list = { }

	for k, item in pairs(inv) do
		item = itemDB:get(item, function() return ni.getInventory().getItemDetail(k) end)
		local key = itemDB:makeKey(item)
		if not list[key] then
			item.key = key
			list[key] = item
		end
	end

	self.grid:setValues(list)
	itemDB:flush()

	return UI.Page.enable(self)
end

function page.grid:getRowTextColor(row)
	if context.state.food == row.key then
		return colors.yellow
	end
	return UI.ScrollingGrid.getRowTextColor(self, row)
end

local function getFood(food)
	for slot,v in pairs(ni.getInventory().list()) do
		local key = itemDB:makeKey(v)
		if key == food then
			local item = ni.getInventory().getItemDetail(slot)
			if item and item.saturation then
				return slot
			end
			break
		end
	end
end

function page:eventHandler(event)
	if event.type == 'grid_select' then
		if context.state.food == event.selected.key then
			context:setState('food')
			self.grid:draw()
		elseif getFood(event.selected.key) then
			context:setState('food', event.selected.key)
			self.grid:draw()
		else
			Sound.play('entity.villager.no')
		end
		return true
	end
end

Event.onInterval(5, function()
	local s, m = pcall(function() -- prevent errors from some mod items
		if context.state.food and ni.getMetaOwner().food.hungry then
			local item = getFood(context.state.food)
			if item then
				ni.getInventory().consume(item)
			end
		end
	end)
	if not s and m then
		_G._syslog(m)
	end
end)

return {
	menuItem = 'Auto-feeder',
	callback = function()
		UI:setPage(page)
	end,
}