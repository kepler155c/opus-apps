local Adapter   = require('core.inventoryAdapter')
local Builder   = require('builder.builder')
local class     = require('opus.class')
local Event     = require('opus.event')
local itemDB    = require('core.itemDB')
local Message   = require('core.message')
local Point     = require('opus.point')
local UI        = require('opus.ui')
local Util      = require('opus.util')

local device     = _G.device
local fs         = _G.fs
local os         = _G.os
local read       = _G.read
local rs         = _G.rs
local turtle     = _G.turtle

local RESOURCE_SLOTS = 14
local FUEL_ITEM      = { id = 'minecraft:coal', dmg = 0 }

local TurtleBuilder = class(Builder)
Util.merge(TurtleBuilder, {
	slots         = { },
})

-- Temp functions until conversion to new adapters is complete
local function convertSingleForward(item)
	item.displayName = item.display_name
	item.name = item.id
	item.damage = item.dmg
	item.count = item.qty
	item.maxCount = item.max_size
	return item
end

local function convertForward(t)
	for _,v in pairs(t) do
		convertSingleForward(v)
	end
	return t
end

local function convertSingleBack(item)
	if item then
		item.id = item.name
		item.dmg = item.damage
		item.qty = item.count
		item.max_size = item.maxCount
		item.display_name = item.displayName
	end
	return item
end

--[[-- SupplyPage --]]--
local supplyPage = UI.Page {
	titleBar = UI.TitleBar {
		title = 'Waiting for supplies',
		previousPage = 'start'
	},
	menuBar = UI.MenuBar {
		y = 2,
		buttons = {
			--{ text = 'Refresh', event = 'refresh', help = 'Refresh inventory' },
			{ text = 'Continue',    event = 'build', help = 'Continue building' },
			{ text = 'Menu',        event = 'menu',  help = 'Return to main menu' },
--      { text = 'Force Craft', event = 'craft', help = 'Request crafting (again)' },
		}
	},
	grid = UI.Grid {
		columns = {
			{ heading = 'Name', key = 'display_name',  width = UI.term.width - 7 },
			{ heading = 'Need', key = 'need',  width = 4                 },
		},
		sortColumn = 'display_name',
		y = 3,
		width = UI.term.width,
		height = UI.term.height - 3
	},
	statusBar = UI.StatusBar {
		columns = {
			{ 'Help', 'help', UI.term.width - 13 },
			{ 'Fuel', 'fuel', 11 }
		}
	},
	accelerators = {
		c = 'craft',
		r = 'refresh',
		b = 'build',
		m = 'menu',
	},
}

function supplyPage:eventHandler(event)
	if event.type == 'build' then
		UI:setPage('start')
		self:sync()
		self.builder:build()

	elseif event.type == 'menu' then
		self.builder:dumpInventory()
		--Builder.status = 'idle'
		UI:setPage('start')
		turtle.setStatus('waiting')

	elseif event.type == 'grid_focus_row' then
		self.statusBar:setValue('help', event.selected.id .. ':' .. event.selected.dmg)
		self.statusBar:draw()

	elseif event.type == 'focus_change' then
		self.statusBar:timedStatus(event.focused.help, 3)
	end

	return UI.Page.eventHandler(self, event)
end

function supplyPage:enable(builder)
	self.builder = builder
	self.grid:setIndex(1)
	self.statusBar:setValue('fuel',
		string.format('Fuel: %dk', math.floor(turtle.getFuelLevel() / 1024)))

	self.timer = Event.onInterval(6, function()
		if self.enabled then
			local s, m = pcall(function()
				self.builder:autocraft(self.builder:getSupplies())
				self:refresh()
				self.statusBar:timedStatus('Refreshed ', 2)
				self:sync()
			end)
			if not s then -- not sure why it's erroring :(
				_G._syslog(m)
			end
		end
	end)
	UI.Page.enable(self)
end

function supplyPage:disable()
	Event.off(self.timer)
end

function supplyPage:setSupplies(supplies)
	local t = { }
	for _,s in pairs(supplies) do
		local key = s.id .. ':' .. s.dmg
		local entry = t[key]
		if not entry then
			entry = Util.shallowCopy(s)
			t[key] = entry
		else
			entry.need = entry.need + s.need
		end
		entry.need = entry.need - turtle.getItemCount(s.index)
	end

	self.grid:setValues(t)
end

function supplyPage:refresh()
	self.statusBar:timedStatus('Refreshed ', 3)
	local supplies = self.builder:getSupplies()
	if #supplies == 0 then
		UI:setPage('blank')
		self:sync()
		self.builder:build()
	else
		self:setSupplies(supplies)
		self.grid:draw()
	end
end

--[[-- Builder --]]--
function TurtleBuilder:getBlockCounts()
	local blocks = Builder.getBlockCounts(self)

	-- add a couple essential items to the supply list to allow replacements
	local wrench = self.subDB:getSubstitutedItem('SubstituteAWrench', 0)
	wrench.qty = 0
	wrench.need = 1
	blocks[wrench.id .. ':' .. wrench.dmg] = wrench

	local fuel = self.subDB:getSubstitutedItem(FUEL_ITEM.id, FUEL_ITEM.dmg)
	fuel.qty = 0
	fuel.need = 1
	blocks[fuel.id .. ':' .. fuel.dmg] = fuel

	blocks['minecraft:piston:0'] = {
		id = 'minecraft:piston',
		dmg = 0,
		qty = 0,
		need = 1,
	}

	return blocks
end

function TurtleBuilder:selectItem(id, dmg)
	for k,s in ipairs(self.slots) do
		if s.qty > 0 and s.id == id and s.dmg == dmg then
			-- check to see if someone pulled items from inventory
			-- or we passed over a hopper
			if turtle.getItemCount(s.index) > 0 then
				if k > 1 and s.qty > 1 then
					table.remove(self.slots, k)
					table.insert(self.slots, 1, s)
				end
				turtle.select(s.index)
				return s
			end
		end
	end
end

function TurtleBuilder:getAirResupplyList(blockIndex)
	local slots = { }

	if self.mode == 'destroy' then
		for i = 1, RESOURCE_SLOTS do
			slots[i] = {
				qty = 0,
				need = 0,
				index = i
			}
		end
	else
		slots = self:getGenericSupplyList(blockIndex)
	end

	local fuel = self.subDB:getSubstitutedItem(FUEL_ITEM.id, FUEL_ITEM.dmg)

	slots[15] = {
		id = 'minecraft:chest',
		dmg = 0,
		qty = 0,
		need = 1,
		index = 15,
	}

	slots[16] = {
		id = fuel.id,
		dmg = fuel.dmg,
		qty = 0,
		need = 64,
		index = 16,
	}

	return slots
end

function TurtleBuilder:getSupplyList(blockIndex)
	local slots, lastBlock = self:getGenericSupplyList(blockIndex)

	slots[15] = {
		id = 'minecraft:piston',
		dmg = 0,
		qty = 0,
		need = 1,
		index = 15,
	}

	local wrench = self.subDB:getSubstitutedItem('SubstituteAWrench', 0)
	slots[16] = {
		id = wrench.id,
		dmg = wrench.dmg,
		qty = 0,
		need = 1,
		index = 16,
	}

	self.slots = slots

	return lastBlock
end

function TurtleBuilder:getGenericSupplyList(blockIndex)
	local slots = { }

	for i = 1, RESOURCE_SLOTS do
		slots[i] = {
			qty = 0,
			need = 0,
			index = i
		}
	end

	local function getSlot(id, dmg)
		-- find matching slot
		local maxStack = itemDB:getMaxCount({ name = id, damage = dmg })
		for _, s in ipairs(slots) do
			if s.id == id and s.dmg == dmg and s.need < maxStack then
				return s
			end
		end
		-- return first available slot
		for _, s in ipairs(slots) do
			if not s.id then
				s.key = id .. ':' .. dmg
				s.id = id
				s.dmg = dmg
				return s
			end
		end
	end

	local lastBlock = blockIndex
	for k = blockIndex, #self.schematic.blocks do
		lastBlock = k
		local b = self.schematic:getComputedBlock(k)

		if b.id ~= 'minecraft:air' then
			local slot = getSlot(b.id, b.dmg)
			if not slot then
				break
			end
			slot.need = slot.need + 1
		end
	end

	for _,s in pairs(slots) do
		if s.id then
			s.display_name = itemDB:getName({ name = s.id, damage = s.dmg })
		end
	end

	return slots, lastBlock
end

function TurtleBuilder:dumpInventory()
	local success = true

	for i = 1, 16 do
		local qty = turtle.getItemCount(i)
		if qty > 0 then
			self.itemAdapter:insert(i, qty)
		end
		if turtle.getItemCount(i) ~= 0 then
			success = false
		end
	end
	turtle.select(1)

	return success
end

function TurtleBuilder:dumpInventoryWithCheck()
	while not self:dumpInventory() do
		print('Storage is full or missing - make space or replace')
		print('Press enter to continue')
		turtle.setHeading(0)
		read()
	end
end

function TurtleBuilder:autocraft(supplies)
	if self.itemAdapter.craftItems then
		local t = { }

		for _,s in pairs(supplies) do
			local key = s.id .. ':' .. s.dmg
			local item = t[key]
			if not item then
				item = {
					id = s.id,
					dmg = s.dmg,
					qty = 0,
				}
				t[key] = item
			end
			item.qty = item.qty + (s.need - s.qty)
		end

		self.itemAdapter:craftItems(convertForward(t))
	end
end

function TurtleBuilder:getSupplies()
	self.itemAdapter:refresh()

	local t = { }
	for _,s in ipairs(self.slots) do
		if s.need > 0 then
			local item = convertSingleBack(self.itemAdapter:getItemInfo({
				name = s.id,
				damage = s.dmg,
				nbtHash = s.nbt_hash,
			}))
			if item then
				s.display_name = item.display_name

				local qty = math.min(s.need - s.qty, item.qty)

				if qty + s.qty > item.max_size then
					qty = item.max_size
					s.need = qty
				end
				if qty > 0 then
					self.itemAdapter:provide(convertSingleForward(item), qty, s.index)
					s.qty = turtle.getItemCount(s.index)
				end
			else
				s.display_name = itemDB:getName({ name = s.id, damage = s.dmg })
			end
		end
		if s.qty < s.need then
			table.insert(t, s)
		end
	end

	return t
end

function TurtleBuilder:refuel()
	while turtle.getFuelLevel() < 4000 do
		print('Refueling')
		turtle.select(1)

		local fuel = self.subDB:getSubstitutedItem(FUEL_ITEM.id, FUEL_ITEM.dmg)

		self.itemAdapter:provide(convertSingleForward(fuel), 64, 1)
		if turtle.getItemCount(1) == 0 then
			print('Out of fuel, add fuel to chest/ME system')
			turtle.setHeading(0)
			turtle.setStatus('waiting')
			os.sleep(5)
		else
			turtle.refuel(64)
		end
	end
end

function TurtleBuilder:inAirDropoff()
	if not device.wireless_modem then
		return false
	end

	self:log('Requesting air supply drop for supply #: ' .. 1)
	while true do
		Message.broadcast('needSupplies', { point = turtle.getPoint(), uid = 1 })
		local _, _, msg, _ = Message.waitForMessage('gotSupplies', 1)

		if not msg or not msg.contents then
			Message.broadcast('supplyList', { uid = 1, slots = self:getAirResupplyList() })
			return false
		end

		turtle.setStatus('waiting')

		if msg.contents.point then
			local pt = msg.contents.point

			self:log('Received supply location')
			os.sleep(0)

			turtle.go(pt)
			os.sleep(.1)  -- random computer is not connected error

			local chestAdapter = Adapter.wrap({ direction = 'down', side = 'top' })

			if not chestAdapter then
				self:log('Chests above is not valid')
				return false
			end

			local oldAdapter = self.itemAdapter
			self.itemAdapter = chestAdapter

			if not self:dumpInventory() then
				self:log('Unable to dump inventory')
				self.itemAdapter = oldAdapter
				return false
			end

			self.itemAdapter = oldAdapter

			Message.broadcast('thanks', { })

			for _ = 1,12 do -- wait til supplier is idle before sending next request
				if turtle.detectUp() then
					os.sleep(.25)
				end
			end
			os.sleep(.1)

			Message.broadcast('supplyList', { uid = 1, slots = self:getAirResupplyList() })

			return true
		end
	end
end

function TurtleBuilder:inAirResupply()
	if not device.wireless_modem then
		return false
	end

	local oldAdapter = self.itemAdapter

	self:log('Requesting air supply drop for supply #: ' .. self.slotUid)
	while true do
		Message.broadcast('needSupplies', { point = turtle.getPoint(), uid = self.slotUid })
		local _, _, msg, _ = Message.waitForMessage('gotSupplies', 1)

		if not msg or not msg.contents then
			self.itemAdapter = oldAdapter
			return false
		end

		turtle.setStatus('waiting')

		if msg.contents.point then
			local pt = msg.contents.point

			self:log('Received supply location')
			os.sleep(0)

			turtle.go(pt)
			os.sleep(.1)  -- random computer is not connected error

			local chestAdapter = Adapter.wrap({ direction = 'down', side = 'top' })

			if not chestAdapter then
				Util.print('not valid')
				read()
			end

			self.itemAdapter = chestAdapter

			if not self:dumpInventory() then
				self.itemAdapter = oldAdapter
				return false
			end
			self:refuel()

			local lastBlock = self:getSupplyList(self.index)
			local supplies = self:getSupplies()

			Message.broadcast('thanks', { })

			self.itemAdapter = oldAdapter

			if #supplies == 0 then

				for _ = 1,12 do -- wait til supplier is idle before sending next request
					if turtle.detectUp() then
						os.sleep(.25)
					end
				end
				os.sleep(.1)
				if lastBlock < #self.schematic.blocks then
					self:sendSupplyRequest(lastBlock)
				else
					Message.broadcast('finished')
				end

				return true
			end
			self:log('Missing supplies - manually resupplying')
			return false
		end
	end
end

function TurtleBuilder:sendSupplyRequest(lastBlock)
	if device.wireless_modem then
		local slots = self:getAirResupplyList(lastBlock)
		self.slotUid = os.clock()
		Message.broadcast('supplyList', { uid = self.slotUid, slots = slots })
	end
end

local function closestEdgePoint(pt, pts, rpt, y)
	pt = Point.copy(pt)
	pt.heading = rpt.heading

	local pta = Point.closest(pt, pts)
	Util.removeByValue(pts, pta)
	local ptb = Point.closest(pt, pts)

	local cpt = { }
	if rpt.x < math.min(pta.x, ptb.x) then
		cpt.x = math.min(pta.x, ptb.x)
	elseif rpt.x > math.max(pta.x, ptb.x) then
		cpt.x = math.max(pta.x, ptb.x)
	else
		cpt.x = rpt.x
	end

	if rpt.z < math.min(pta.z, ptb.z) then
		cpt.z = math.min(pta.z, ptb.z)
	elseif rpt.z > math.max(pta.z, ptb.z) then
		cpt.z = math.max(pta.z, ptb.z)
	else
		cpt.z = rpt.z
	end

	cpt.y = y
	return cpt
end

function TurtleBuilder:getBuildingCorner(y)
	local pts = {
		{ x = -1,                   z = -1,                    y = 0 },
		{ x = -1,                   z = self.schematic.length, y = 0 },
		{ x = self.schematic.width, z = -1,                    y = 0 },
		{ x = self.schematic.width, z = self.schematic.length, y = 0 },
	}
	return closestEdgePoint(self.supplyPoint, pts, turtle.getPoint(), y)
end

function TurtleBuilder:gotoSupplyPoint()
	if not Point.same(turtle.getPoint(), self.supplyPoint) then
		-- so we don't end up pathfinding through a building
		-- go to the corner closest to the supplies point
		-- pathfind the rest of the way
		local pt = self:getBuildingCorner(turtle.point.y)
		turtle.go({ x = pt.x, z = pt.z })
		turtle.set({
			digPolicy = 'digNone',
			attackPolicy = 'attackNone',
		})
		turtle.pathfind(self.supplyPoint)
		os.sleep(.1) -- random 'Computer is not connected' error...
	end
end

function TurtleBuilder:resupply()
	if self.slotUid and self:inAirResupply() then
		os.queueEvent('build')
		return
	end

	turtle.setStatus('resupplying')

	self:log('Resupplying')
	self:gotoSupplyPoint()
	self:dumpInventoryWithCheck()
	self:refuel()
	local lastBlock = self:getSupplyList(self.index)
	if lastBlock < #self.schematic.blocks then
		self:sendSupplyRequest(lastBlock)
	elseif device.wireless_modem then
		Message.broadcast('finished')
	end
	os.sleep(1)
	local supplies = self:getSupplies()

	if #supplies == 0 then
		os.queueEvent('build')
	else
		turtle.setHeading(0)
		self:autocraft(supplies)
		supplyPage:setSupplies(supplies)
		UI:setPage(supplyPage, self)
	end
end

function TurtleBuilder:placeDown(slot)
	return turtle.placeDown(slot.index)
end

function TurtleBuilder:placeUp(slot)
	return turtle.placeUp(slot.index)
end

function TurtleBuilder:place(slot)
	return turtle.place(slot.index)
end

function TurtleBuilder:getWrenchSlot()
	local wrench = self.subDB:getSubstitutedItem('SubstituteAWrench', 0)
	return self:selectItem(wrench.id, wrench.dmg)
end

-- figure out our orientation in the world
function TurtleBuilder:getTurtleFacing()
	local directions = {
		[5] = 2,
		[3] = 3,
		[4] = 0,
		[2] = 1,
	}

	local function getItem(item)
		turtle.select(1)
		local msg = false
		while true do
			self.itemAdapter:provide(item, 1, 1)
			if turtle.getItemCount(1) == 1 then
				break
			end
			if not msg then
				print('Place ' .. itemDB:getName(item) .. ' in supply chest')
				msg = true
			end
			os.sleep(1)
		end
	end

	getItem({ name = 'minecraft:piston', damage = 0 })
	turtle.placeUp()
	local _, bi = turtle.inspectUp()
	turtle.digUp()
	self:dumpInventoryWithCheck()

	if directions[bi.metadata] then
		self.facing = directions[bi.metadata]
		return
	end

	-- if the piston faces up when placed above, then this version
	-- has the stair bug
	self.stairBug = true

	getItem({ name = 'minecraft:chest', damage = 0 })
	turtle.placeUp()
	local _, bi2 = turtle.inspectUp()
	turtle.digUp()
	self:dumpInventoryWithCheck()

	self.facing = directions[bi2.metadata]
end

function TurtleBuilder:wrenchBlock(side, facing, cache)
	local s = self:getWrenchSlot()

	if not s then
		return false
	end

	local key = turtle.getPoint().heading .. '-' .. facing
	if cache then
		local count = cache[side][key]

		if count then
			turtle.select(s.index)
			for _ = 1,count do
				turtle.getAction(side).place()
			end
			return true
		end
	end

	local directions = {
		[5] = 'east',
		[3] = 'south',
		[4] = 'west',
		[2] = 'north',
		[0] = 'down',
		[1] = 'up',
	}

	if turtle.getHeadingInfo(facing).heading < 4 then
		local offsetDirection = (self.facing +
								turtle.getHeadingInfo(facing).heading) % 4
		facing = turtle.getHeadingInfo(offsetDirection).direction
	end

	local count = 0
	print('determining wrench count')
	for _ = 1, 6 do
		local _, bi = turtle.getAction(side).inspect()

		if facing == directions[bi.metadata] then
			if cache then
				cache[side][key] = count
			end
			return true
		end
		count = count + 1
		turtle.getAction(side).place()
	end

	return false
end

function TurtleBuilder:rotateBlock(side, facing)
	if self:getWrenchSlot() then
		for _ = 1, facing do
			turtle.getAction(side).place()
		end
		return true
	end
end

-- place piston, wrench piston to face downward, extend, remove piston
function TurtleBuilder:placePiston(b)
	local ps = self:selectItem('minecraft:piston', 0)
	local ws = self:getWrenchSlot()

	if not ps or not ws then
		b.needResupply = true
		-- a hopper may have eaten the piston
		return
	end

	if not turtle.place(ps.index) then
		return
	end

	if self.wrenchSucks then
		turtle.turnRight()
		turtle.forward()
		turtle.turnLeft()
		turtle.forward()
		turtle.turnLeft()
	end

	--wrench piston to point downwards
	local success = self:wrenchBlock('forward', 'down', self.pistonFacings)

	rs.setOutput('front', true)
	os.sleep(.25)
	rs.setOutput('front', false)
	os.sleep(.25)
	turtle.select(ps.index)
	turtle.dig()

	if not success and not self.wrenchSucks then
		self.wrenchSucks = true
		success = self:placePiston(b)
	end

	return success
end

function TurtleBuilder:go(x, z, y, heading)
	if not turtle.go({ x = x, z = z, y = y, heading = heading }) then
		print('stuck')
		print('Press enter to continue')
		os.sleep(1)
		turtle.setStatus('stuck')
		read()
	end
end

-- goto used when turtle could be below travel plane
-- if the distance is no more than 1 block, there's no need to pop back to the travel plane
function TurtleBuilder:gotoEx(x, z, y, h, travelPlane)
	local pt = turtle.getPoint()
	local distance = math.abs(pt.x - x) + math.abs(pt.z - z)

	-- following code could be better
	if distance == 0 then
		turtle.gotoY(y)
	elseif distance == 1 then
		if pt.y < y then
			turtle.gotoY(y)
		end
	elseif distance > 1 then
		self:gotoTravelPlane(travelPlane)
	end
	self:go(x, z, y, h)
end

function TurtleBuilder:placeDirectionalBlock(b, slot, travelPlane)
	local d = b.direction

	local function getAdjacentPoint(pt, direction)
		local hi = turtle.getHeadingInfo(direction)
		return { x = pt.x + hi.xd, z = pt.z + hi.zd, y = pt.y + hi.yd, heading = (hi.heading + 2) % 4 }
	end

	local directions = {
		[ 'north' ] = 'north',
		[ 'south' ] = 'south',
		[ 'east'  ] = 'east',
		[ 'west'  ] = 'west',
	}
	if directions[d] then
		self:gotoEx(b.x, b.z, b.y, turtle.getHeadingInfo(directions[d]).heading, travelPlane)
		b.placed = self:placeDown(slot)
	end

	if d == 'top' then
		self:gotoEx(b.x, b.z, b.y+1, nil, travelPlane)
		if self:placeDown(slot) then
			turtle.goback()
			b.placed = self:placePiston(b)
		end
	end

	if d == 'bottom' then
		local t = {
			[1] = getAdjacentPoint(b, 'east'),
			[2] = getAdjacentPoint(b, 'south'),
			[3] = getAdjacentPoint(b, 'west'),
			[4] = getAdjacentPoint(b, 'north'),
		}

		local c = Point.closest(turtle.getPoint(), t)
		self:gotoEx(c.x, c.z, c.y, c.heading, travelPlane)

		if self:place(slot) then
			turtle.up()
			b.placed = self:placePiston(b)
		end
	end

	local stairDownDirections = {
		[ 'north-down' ] = 'north',
		[ 'south-down' ] = 'south',
		[ 'east-down'  ] = 'east',
		[ 'west-down'  ] = 'west'
	}
	if stairDownDirections[d] then
		self:gotoEx(b.x, b.z, b.y+1, turtle.getHeadingInfo(stairDownDirections[d]).heading, travelPlane)
		if self:placeDown(slot) then
			turtle.goback()
			b.placed = self:placePiston(b)
		end
	end

	local stairUpDirections = {
		[ 'north-up' ] = 'south',
		[ 'south-up' ] = 'north',
		[ 'east-up'  ] = 'west',
		[ 'west-up'  ] = 'east'
	}
	if stairUpDirections[d] then
		local isSouth = (self.facing +
										turtle.getHeadingInfo(stairUpDirections[d]).heading) % 4 == 1

		if not self.stairBug then
			isSouth = false
		end

		if isSouth then
			-- for some reason, the south facing stair doesn't place correctly
			-- jump through some hoops to place it
			self:gotoEx(b.x, b.z, b.y, (turtle.getHeadingInfo(stairUpDirections[d]).heading + 2) % 4, travelPlane)
			if self:placeUp(slot) then
				turtle.goback()
				turtle.gotoY(turtle.getPoint().y + 2)
				b.placed = self:placePiston(b)
				turtle.down()
				b.placed = self:placePiston(b)

				-- stop debug message below since we are pointing in wrong direction
				b.heading = turtle.getPoint().heading
			end
		else
			local hi = turtle.getHeadingInfo(stairUpDirections[d])
			self:gotoEx(b.x - hi.xd, b.z - hi.zd, b.y, hi.heading, travelPlane)
			if self:place(slot) then
				turtle.up()
				b.placed = self:placePiston(b)
			end
		end
	end

	local horizontalDirections = {
		[ 'east-west-block'   ] = { 'east', 'west' },
		[ 'north-south-block' ] = { 'north', 'south' },
	}
	if horizontalDirections[d] then

		local t = {
			[1] = getAdjacentPoint(b, horizontalDirections[d][1]),
			[2] = getAdjacentPoint(b, horizontalDirections[d][2]),
		}

		local c = Point.closest(turtle.getPoint(), t)
		self:gotoEx(c.x, c.z, c.y, c.heading, travelPlane)

		if self:place(slot) then
			turtle.up()
			b.placed = self:placePiston(b)
		end
	end

	local pistonDirections = {
		[ 'piston-north' ] = 'north',
		[ 'piston-south' ] = 'south',
		[ 'piston-west'  ] = 'west',
		[ 'piston-east'  ] = 'east',
		[ 'piston-down'  ] = 'down',
		[ 'piston-up'    ] = 'up',
	}

	if pistonDirections[d] then
		-- why are pistons so broke in cc 1.7 ??????????????????????

		local ws = self:getWrenchSlot()

		if not ws then
			b.needResupply = true
			-- a hopper may have eaten the piston
			return false
		end

		-- piston turns relative to turtle position :)
		local rotatedPistonDirections = {
			[ 'piston-east' ] = 0,
			[ 'piston-south' ] = 1,
			[ 'piston-west' ] = 2,
			[ 'piston-north' ] = 3,
		}

		self:gotoEx(b.x, b.z, b.y, nil, travelPlane)

		local heading = rotatedPistonDirections[d]
		if heading and turtle.getPoint().heading % 2 ~= heading % 2 then
			turtle.setHeading(heading)
		end

		if self:placeDown(slot) then
			b.placed = self:wrenchBlock('down', pistonDirections[d], self.pistonFacings)
		end
	end

	local wrenchDirections = {
		[ 'wrench-down' ] = 'down',
		[ 'wrench-up'   ] = 'up',
	}

	if wrenchDirections[d] then

		local ws = self:getWrenchSlot()

		if not ws then
			b.needResupply = true
			-- a hopper may have eaten the piston
			return false
		end

		self:gotoEx(b.x, b.z, b.y, nil, travelPlane)

		if self:placeDown(slot) then
			b.placed = self:wrenchBlock('down', wrenchDirections[d])
		end
	end

	local doorDirections = {
		[ 'east-door' ] = 'east',
		[ 'south-door' ] = 'south',
		[ 'west-door'  ] = 'west',
		[ 'north-door'  ] = 'north',
	}
	if doorDirections[d] then
		local hi = turtle.getHeadingInfo(doorDirections[d])
		self:gotoEx(b.x - hi.xd, b.z - hi.zd, b.y - 1, hi.heading, travelPlane)
		b.placed = self:place(slot)
	end

	local blockDirections = {
		[ 'north-block' ] = 'north',
		[ 'south-block' ] = 'south',
		[ 'east-block'  ] = 'east',
		[ 'west-block'  ] = 'west',
	}
	if blockDirections[d] then
		local hi = turtle.getHeadingInfo(blockDirections[d])
		self:gotoEx(b.x - hi.xd, b.z - hi.zd, b.y-1, hi.heading, travelPlane)
		b.placed = self:place(slot)
	end

	if b.facing then
		self:rotateBlock('down', b.facing)
	end

-- debug
if d ~= 'top' and d ~= 'bottom' and not horizontalDirections[d] and not pistonDirections[d] then
	if not b.heading or turtle.getHeading() ~= b.heading then
		self:log(d .. ' - ' .. turtle.getHeading() .. ' - ' .. (b.heading or 'nil'))
		--read()
	end
end

	return b.placed
end

-- find the highest y in the last 2 planes
function TurtleBuilder:findTravelPlane(index)
	local travelPlane

	for i = index, 1, -1 do
		local b = self.schematic.blocks[i]

		local y = b.y
		if b.twoHigh then
			y = y + 1
		end
		if not travelPlane or y > travelPlane then
			travelPlane = y
		elseif travelPlane and travelPlane - y > 2 then
			break
		end
	end

	return travelPlane or 0
end

function TurtleBuilder:gotoTravelPlane(travelPlane)
	if travelPlane > turtle.getPoint().y then
		turtle.gotoY(travelPlane)
	end
end

function TurtleBuilder:build()
	local direction = 1
	local last = #self.schematic.blocks
	local minFuel = self.schematic.height + self.schematic.width + self.schematic.length + 100
	local throttle = Util.throttle()

	if self.mode == 'destroy' then
		direction = -1
		last = 1
		turtle.setStatus('destroying')
	else
		turtle.setStatus('building')
	end

	local travelPlane  = self:findTravelPlane(self.index)

	local pt = self:getBuildingCorner(travelPlane)
	turtle.pathfind({ x = pt.x, z = pt.z, y = travelPlane })
	turtle.set({
		digPolicy = 'dig',
		attackPolicy = 'attack',
	})

	for i = self.index, last, direction do
		self.index = i

		local b = self.schematic:getComputedBlock(i)

		if b.id ~= 'minecraft:air' then

			if self.mode == 'destroy' then

				b.heading = nil -- don't make the supplier follow the block heading
				self:logBlock(self.index, b)
				if b.y ~= turtle.getPoint().y then
					turtle.gotoY(b.y)
				end
				self:go(b.x, b.z, b.y)
				turtle.digDown()

				-- if no supplier, then should fill all slots

				if turtle.getItemCount(RESOURCE_SLOTS) > 0 or turtle.getFuelLevel() < minFuel then
					if turtle.getFuelLevel() < minFuel or not self:inAirDropoff() then
						self:gotoSupplyPoint()
						self:dumpInventoryWithCheck()
						self:refuel()
					end
					turtle.setStatus('destroying')
				end

			else -- Build mode

				local slot = self:selectItem(b.id, b.dmg)
				if not slot or turtle.getFuelLevel() < minFuel then

					self:gotoTravelPlane(travelPlane)
					self:resupply()
					return
				end
				local y = b.y
				if b.twoHigh then
					y = b.y + 1
				end
				if y > travelPlane then
					travelPlane = y
				end

				self:logBlock(self.index, b)

				if b.direction then
					b.needResupply = false
					self:placeDirectionalBlock(b, slot, travelPlane)
					if b.needResupply then -- lost our piston in a hopper probably
						self:gotoTravelPlane(travelPlane)
						self:resupply()
						return
					end
				else
					self:gotoTravelPlane(travelPlane)
					self:go(b.x, b.z, b.y)
					b.placed = self:placeDown(slot)
				end

				if b.placed then
					slot.qty = slot.qty - 1
				else
					print('failed to place block')
				end
			end
			if self.mode == 'destroy' then
				self:saveProgress(math.max(self.index, 1))
			else
				self:saveProgress(self.index + 1)
			end
		else
			throttle() -- sleep in case there are a large # of skipped blocks
		end

		if turtle.isAborted() then
			turtle.setStatus('aborting')
			turtle.abort(false)
			self:gotoTravelPlane(travelPlane)
			self:gotoSupplyPoint()
			turtle.setHeading(0)
			self:dumpInventory()
			Event.exitPullEvents()
			print('Aborted')
			return
		end
	end

	if device.wireless_modem then
		Message.broadcast('finished')
	end

	self:gotoTravelPlane(travelPlane)
	self:gotoSupplyPoint()
	turtle.setHeading(0)
	self:dumpInventory()

	for _ = 1, 4 do
		turtle.turnRight()
	end

	fs.delete(self.schematic.filename .. '.progress')
	print('Finished')
	Event.exitPullEvents()
end

function TurtleBuilder:begin()
	turtle.reset()
	self:dumpInventory()
	self:refuel()
	self:getTurtleFacing()

	if self.loc.x then
		self.supplyPoint = {
			x = self.loc.x - self.loc.rx - 1,
			y = self.loc.y - self.loc.ry,
			z = self.loc.z - self.loc.rz - 1,
		}
		Point.rotate(self.supplyPoint, self.facing)
	else
		self.supplyPoint = { x = -1, y = 0, z = -1 }
	end
	turtle.setPoint(self.supplyPoint)

	-- reset piston cache in case wrench was substituted
	self.pistonFacings = {
		down = { },
		forward = { },
	}

	if self.mode == 'destroy' then
		if device.wireless_modem then
			Message.broadcast('supplyList', { uid = 1, slots = self:getAirResupplyList() })
		end
		print('Beginning destruction')
		self:build()
	else
		print('Starting build')
		self:resupply()
	end
end

return TurtleBuilder
