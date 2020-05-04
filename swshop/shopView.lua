local Config     = require('opus.config')
local Event      = require('opus.event')
local itemDB     = require('core.itemDB')
local Milo       = require('milo')
local Sound      = require('opus.sound')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local colors     = _G.colors
local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell

local config = Config.load('shop')
local shopTab

local function startShop(node)
	if shopTab then
		multishell.terminate(shopTab)
	end
	shopTab = shell.openTab('/packages/swshop/swshop.lua', node.name)
end

-- node has been reconfigured
Event.on('shop_restart', function(_, node)
	startShop(node)
end)

-- milo is being terminated
Event.on('terminate', function()
	if shopTab then
		multishell.terminate(shopTab)
		shopTab = nil
	end
end)

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
		header = UI.Window {
			backgroundColor = 'primary',
			ey = 3,
		},
		grid = UI.Grid {
			y = 4, ey = -7,
			headerHeight = 3,
			headerBackgroundColor = 'tertiary',
			backgroundSelectedColor = colors.black,
			unfocusedBackgroundSelectedColor = 'tertiary',
			columns = {
				{ heading = 'Stock',   key = 'count',     width = 6, align = 'right' },
				{ heading = 'Name',    key = 'displayName' },
				{ heading = '   Price', key = 'price',    width = 9, align = 'right' },
				{ heading = 'Address', key = 'address',   width = 12 },
			},
			sortColumn = 'displayName',
		},
		footer = UI.Window {
			y = -6,
			backgroundColor = 'tertiary',
			prevButton = UI.Button {
				x = 2, y = 3, height = 3, width = 5,
				event = 'previous',
				backgroundColor = 'secondary',
				text = ' \017 ',
			},
			nextButton = UI.Button {
				x = -6, y = 3, height = 3, width = 5,
				event = 'next',
				backgroundColor = 'secondary',
				text = ' \016 ',
			},
			info = UI.Window {
				x = 9, ex = -9,
				textColor = colors.white,
			}
		},
		timestamp = os.clock(),
	}

	function page.header:draw()
		self:clear()
		if node.header then
			self:centeredWrite(2, node.header, nil, colors.white)
		end
		self:write(self.width - 15, 3, 'powered by Milo', nil, 'tertiary')
	end

	function page.footer.info:draw()
		self:clear()
		local selected = page.grid:getSelected()

		if selected then
			if selected.info then
				self:centeredWrite(2, selected.info)
			end

			self:centeredWrite(4, 'To purchase:')
			self:centeredWrite(5, string.format('/pay %s@%s.kst <amount>', selected.name, node.domain))
		end
	end

	function page.grid:getRowTextColor(row, selected)
		if row.count < 1 then
			return colors.red
		end
		if selected then
			return colors.yellow
		end
		return UI.Grid:getRowTextColor(row, selected)
	end

	function page.grid:getDisplayValues(row)
		row = Util.shallowCopy(row)
		row.count = Util.toBytes(row.count) .. ' '
		row.price = string.format('%s kst ', row.price)
		row.address = row.name
		return row
	end

	function page:eventHandler(event)
		if event.type == 'next' then
			self.grid:emit({ type = 'scroll_down' })

		elseif event.type == 'previous' then
			self.grid:emit({ type = 'scroll_up' })

		elseif event.type == 'grid_focus_row' then
			self.footer:draw()

		else
			return UI.Page.eventHandler(self, event)
		end

		Event.onTimeout(.1, function()
			self:setFocus(self.grid)
			self:sync()
		end)
		return true
	end

	function page:refresh()
		local list = Milo:listItems()
		self.grid.values = { }
		for k,v in pairs(config) do
			local item = list[k] or itemDB:get(k)
			if item and (node.showOutOfStock or item.count > 0) then
				table.insert(self.grid.values, {
					displayName = item.displayName,
					count = item.count or 0,
					name = v.name,
					price = v.price,
					info = v.info,
				})
			end
		end
		self.grid:update()
		self.grid:draw()
	end

	function page:update()
		page:refresh()
		page:sync()
	end

	local chars = { '\183', '\7', '\186', '\7' }
	Event.onInterval(1, function()
		local ch = chars[math.floor(os.clock() % #chars) + 1]
		page.header:write(2, 2, ch)
		page.header:write(page.header.width - 1, 2, ch)
		page:sync()
	end)

	UI:setPage(page)
	return page
end

local pages = { }

-- called when an item to sell has been changed
Event.on('shop_refresh', function()
	config = Config.load('shop')
end)

-- called from the shop when an item has been purchased
Event.on('shop_provide', function(_, item, quantity, uid)
	Milo:queueRequest({ }, function()
		local count = Milo:eject(itemDB:splitKey(item), quantity)
		os.queueEvent('shop_provided', uid, count)
		Sound.play('entity.player.levelup')
	end)
end)

--[[ Task ]]--
local StoreTask = {
	name = 'shop',
	priority = 30,
}

function StoreTask:cycle(context)
	for node in context.storage:filterActive('shop') do
		if not pages[node.name] then
			startShop(node)
			pages[node.name] = createPage(node)
		end
		-- update the display
		pages[node.name]:update()
	end
end

Milo:registerTask(StoreTask)
