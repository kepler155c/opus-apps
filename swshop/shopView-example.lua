local Config     = require('config')
local Event      = require('event')
local itemDB     = require('core.itemDB')
local Milo       = require('milo')

local multishell = _ENV.multishell
local os         = _G.os
local shell      = _ENV.shell

local config = Config.load('shop')
local shopTab

-- You will need to register this plugin in usr/config/milo.state
-- replace the shopView entry with your file name.

--[[ Display ]]--
local function showListing(node)
	local mon = node.adapter
	local list = Milo:listItems()

	mon.clear()
	local i = 1

	for k,v in pairs(config) do
		local item = list[k]
		if item and item.count > 0 then
			mon.setCursorPos(1, i)
			mon.write(string.format('%d  %s: %d kst', v.count, v.displayName, v.price))
			mon.setCursorPos(1, i + 1)
			mon.write(v.info)
			i = i + 2
		end
	end
end

-- everything below is important to keep
local function startShop(node)
	if shopTab then
		multishell.terminate(shopTab)
	end
	shopTab = shell.openTab('/packages/swshop/swshop.lua', node.domain, node.password)
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

-- called when an item to sell has been changed
Event.on('shop_refresh', function()
	config = Config.load('shop')
end)

-- called from the shop when an item has been purchased
Event.on('shop_provide', function(_, item, quantity, uid)
	Milo:queueRequest({ }, function()
		local count = Milo:eject(itemDB:splitKey(item), quantity)
		os.queueEvent('shop_provided', uid, count)
	end)
end)

--[[ Task ]]--
local StoreTask = {
	name = 'shop',
	priority = 30,
}

function StoreTask:cycle(context)
	local node = context.storage:filterActive('shop')()
	if node then
		-- a monitor has been configured
		if not shopTab then
			-- first time running
			startShop(node)
		end

		showListing(node)
	end
end

Milo:registerTask(StoreTask)
