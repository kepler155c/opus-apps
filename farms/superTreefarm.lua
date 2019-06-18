local Equipper   = require('turtle.equipper')
local GPS        = require('gps')
local Point      = require('point')
local Util       = require('util')

local fs         = _G.fs
local os         = _G.os
local peripheral = _G.peripheral
local turtle     = _G.turtle

local STARTUP_FILE = 'usr/autorun/superTreefarm.lua'

local FUEL_DIRE    = 10
local FUEL_GOOD    = 1000

local MIN_CHARCOAL = 24
local MIN_SAPLINGS = 32
local MAX_SAPLINGS = 48

local RADIUS_X     = 2
local RADIUS_Z     = 3

local GRID = {
	TL = { x =  8, y = 0, z = -7 },
	TR = { x =  8, y = 0, z =  8 },
	BL = { x = -7, y = 0, z = -7 },
	BR = { x = -7, y = 0, z =  8 },
}

local HOME_PT = { x = 0, y = 0, z = 0, heading = 0 }

local CHARCOAL       = 'minecraft:coal:1'
local CHEST          = 'minecraft:chest:0'
local DIRT           = 'minecraft:dirt:0'
local PICKAXE        = 'minecraft:diamond_pickaxe'
local FURNACE        = 'minecraft:furnace:0'
local LOG            = 'minecraft:log'
local LOG2           = 'minecraft:log2'
local OAK_SAPLING    = 'minecraft:sapling:0'
local SAPLING        = 'minecraft:sapling'
local SCANNER        = 'plethora:module:2'
local SENSOR         = 'plethora:module:3'

local retain = Util.transpose {
	PICKAXE,
	CHARCOAL,
	SAPLING,
	SCANNER,
	SENSOR,
}

local state = Util.readTable('usr/config/superTreefarm') or { }

local clock = os.clock()

local function setState(key, value)
	state[key] = value
	Util.writeTable('usr/config/superTreefarm', state)
end

local function refuel()
	if turtle.getFuelLevel() < FUEL_GOOD then
		local charcoal = turtle.getItemCount(CHARCOAL)
		--if charcoal > 1 then
			turtle.refuel(CHARCOAL, math.min(charcoal, MIN_CHARCOAL / 2))
			print('fuel: ' .. turtle.getFuelLevel())
		--end
	end
	return true
end

local function makeCharcoal()
	local slots = turtle.getSummedInventory()

	local function getLogSlot()
		local maxslot = { count = 0 }
		for k,slot in pairs(slots) do
			if string.match(k, 'minecraft:log') then
				if slot.count > maxslot.count then
					maxslot = slot
				end
			end
		end
		return maxslot
	end

	if turtle.pathfind(Point.above(state.furnace)) then
		pcall(function()
			local f = peripheral.wrap('bottom')
			local inv = f.list()

			if inv[3] and
				(not slots[CHARCOAL] or
				slots[CHARCOAL].count < MIN_CHARCOAL) then
				f.pushItems('up', 3, 24)
			end

			if turtle.has(CHARCOAL) and turtle.getFuelLevel() > 100 then
				local count = inv[2] and inv[2].count or 0
				if count < 8 then
					f.pullItems('up', turtle.getSlot(CHARCOAL).index, 8-count, 2)
				end
			else
				slots = turtle.getSummedInventory()
				local slot = getLogSlot(slots)
				if slot.count > 0 then
					local s = turtle.getSlot(slot.key)
					f.pullItems('up', s.index, 1, 2)
				end
			end

			local count = inv[1] and inv[1].count or 0
			if count < 32 then
				for key, slot in pairs(turtle.getSummedInventory()) do
					if string.match(key, 'minecraft:log') then
						if turtle.dropDown(key, 32-count) then
							count = count + slot.count
							if count >= 32 then
								break
							end
						end
					end
				end
			end
		end)
	end

	return true
end

local function createFurnace()
	if not state.furnace then
		if not turtle.has(FURNACE) then
			error('Turtle must have a furnace')
		end

		print('Adding a furnace')
		local pt = Point.below(HOME_PT)
		if not turtle.placeDownAt(pt, FURNACE) then
			error('Error placing furnace')
		end
		setState('furnace', pt)
	end
end

local function createChests()
	if not state.chest and turtle.getFuelLevel() > 1 then
		if not turtle.has(CHEST) then
			error('Turtle must have a chest')
		end

		print('Adding storage')

		local pt = Point.below(HOME_PT)
		pt.x = pt.x - 1

		if not turtle.placeDownAt(pt, CHEST) then
			error('Error placing chest')
		end
		setState('chest', pt)

		turtle.dropDown(DIRT)
	end
	return true
end

local function getSaplings()
	local slots = turtle.getSummedInventory()
	local saplings = { }

	for _, slot in pairs(slots) do
		if slot.name == SAPLING then
			table.insert(saplings, slot)
		end
	end

	if #saplings == 0 then
		table.insert(saplings, { name = OAK_SAPLING, count = 0 })
	end

	return saplings
end

local function dropOffItems()
	local slots = turtle.getSummedInventory()

	if state.chest and
			slots[CHARCOAL] and
			slots[CHARCOAL].count >= MIN_CHARCOAL and
			(turtle.getItemCount(LOG) > 16 or
			turtle.getItemCount(LOG2) > 16) then

		print('Storing logs')
		turtle.pathfind(Point.above(state.chest))

		for k,v in pairs(turtle.getInventory()) do
			if v.count > 0 and not retain[v.name] and not retain[v.key] then
				turtle.select(k)
				turtle.dropDown()
			end
		end
	end

	return true
end

local function eatSaplings()
	Util.each(getSaplings(), function(sapling)
		if sapling.count > MAX_SAPLINGS then
			turtle.refuel(sapling.key, sapling.count - MAX_SAPLINGS)
		end
	end)
	return true
end

local function randomSapling()
	local saplings = getSaplings()
	local sapling = saplings[math.random(1, #saplings)]

	if sapling.count > 0 then
		return sapling.key
	end
end

local function makeKey(b)
	return table.concat({ b.x, b.y, b.z }, ':')
end

local function findDroppedSaplings()
	local sensor = Equipper.equipLeft('plethora:sensor')
	local raw = sensor.sense()

	return Util.reduce(raw, function(acc, b)
		Point.rotate(b, state.home.heading)
		b.x = Util.round(b.x) + turtle.point.x
		b.y = math.ceil(b.y) + turtle.point.y
		b.z = Util.round(b.z) + turtle.point.z
		if b.y == 0 and string.find(b.displayName, 'sapling', 1, true) then
			b.sapling = true
			acc[makeKey(b)] = b
		end
		return acc
	end, { })
end

local function scan(pt, filter, blocks)
	turtle.pathfind(pt)

	local scanner = Equipper.equipLeft('plethora:scanner')
	local raw = scanner.scan()

	return Util.reduce(raw, function(acc, b)
		if b.y >= 0 then
			Point.rotate(b, state.home.heading)
			b.x = b.x + turtle.point.x
			b.y = b.y + turtle.point.y
			b.z = b.z + turtle.point.z
			if filter(b) then
				acc[makeKey(b)] = b
			end
		end
		return acc
	end, blocks or { })
end

local function getPlantLocations(blocks)
	for _,sapling in pairs(state.trees) do
		local key = makeKey(sapling)
		local b = blocks[key]
		if b then
			if b.name == SAPLING then
				blocks[key] = nil
			else
				b.plant = true
			end
		elseif turtle.getFuelLevel() > 100 or sapling.x == 1 and sapling.z == 0 then
			b = Util.shallowCopy(sapling)
			b.plant = true
			blocks[key] = b
		end
	end
end

local function desperateRefuel()
	local fuels = { CHARCOAL, LOG, LOG2 }

	if turtle.getFuelLevel() < FUEL_DIRE then
		while true do
			for _, fuel in pairs(fuels) do
				if turtle.has(fuel) then
					turtle.refuel(fuel, 1)
					print('fuel: ' .. turtle.getFuelLevel())
					turtle.select(1)
					break
				end
			end
			if turtle.getFuelLevel() > 0 then
				break
			end
			print('Out of fuel')
			print('Add logs or charcoal to turtle')
			os.pullEvent('turtle_inventory')
		end
	end
end

local function fellTrees(blocks)
	turtle.select(1)

	for pt in Point.iterateClosest(turtle.point, blocks) do
		-- initial tree
		if turtle.getFuelLevel() == 0 then
			if not turtle.digAt(pt) then
				break
			end
			desperateRefuel()
		end

		if pt.y == 0 then
			if pt.sapling then
				repeat until not turtle.suckDownAt(pt)
			elseif pt.plant then
				local s = randomSapling()

				if pt.name and pt.name ~= SAPLING then
					turtle.digDownAt(pt)
				end
				if s then
					turtle.placeDownAt(pt, s)
					turtle.select(1)
				end
			end
		else
			turtle.digAt(pt)
		end
		os.queueEvent('canvas', {
			type = 'canvas_remove',
			data = { pt },
		})
	end

	turtle.pathfind(HOME_PT)

	return true
end

local function fell()
	local function filter(b)
		return b.name == LOG or b.name == LOG2 or b.name == SAPLING
	end

	local fuel = turtle.getFuelLevel()
	local sensed = { }

	-- determine if we need saplings
	if not Util.every(getSaplings(), function(sapling)
			return sapling.count >= MIN_SAPLINGS
		end) then
			sensed = findDroppedSaplings()
	end

	-- low scan
	local blocks = scan(HOME_PT, filter)
	local pt = Util.shallowCopy(HOME_PT)
	while Util.any(blocks, function(b) return b.y > pt.y + 6 end) do
		-- tree might be above low scan range, do a scan higher up
		Equipper.equipLeft(PICKAXE)
		pt.y = pt.y + 8
		blocks = scan(pt, filter, blocks)
	end

	Util.merge(blocks, sensed)

	-- add any locations that need saplings
	getPlantLocations(blocks)

	Equipper.equipLeft(PICKAXE)

	os.queueEvent('canvas', {
		type = 'canvas_update',
		data = blocks,
	})
	if not Util.empty(blocks) then
		print('Chopping')

		fellTrees(blocks)

		print('Used ' .. (fuel - turtle.getFuelLevel()) .. ' fuel')
	end

	return true
end

local function setTrees()
	if not state.trees then
		state.trees = { }
		for x = -RADIUS_X, RADIUS_X, 1 do
			for z = -RADIUS_Z, RADIUS_Z, 1 do
				if z ~= 0 or x > 0 then
					local tree = { x = x, y = 0, z = z }
					table.insert(state.trees, tree)
				end
			end
		end
		setState('trees', state.trees)
	end
end

local function findHome()
	local pt = GPS.getPoint(2) or error('GPS not found')

	local scanner = Equipper.equipLeft('plethora:scanner')

	local facing = scanner.getBlockMeta(0, 0, 0).state.facing
	pt.heading = Point.facings[facing].heading

	Equipper.equipLeft(PICKAXE)

	if not state.home then
		setState('home', pt)
	end

	-- convert to relative coordinates
	turtle.set({
		point = {
			x = pt.x - state.home.x,
			y = pt.y - state.home.y,
			z = pt.z - state.home.z,
			heading = pt.heading,
		},
		reference = state.home,
	})

	Point.rotate(turtle.point, state.home.heading)
	turtle.setHeading(state.home.heading)
	turtle.point.heading = 0

	turtle.setPathingBox({
		x  = GRID.TL.x,
		y  = GRID.TL.y,
		z  = GRID.TL.z,
		ex = GRID.BR.x,
		ey = 32,
		ez = GRID.BR.z,
	})
end

local function returnHome()
	turtle.pathfind(HOME_PT)
	return true
end

local function updateClock()
	local ONE_HOUR = 50

	if os.clock() - clock > ONE_HOUR then
		clock = os.clock()
	else
		print('sleeping for ' .. math.floor(ONE_HOUR - (os.clock() - clock)))
		os.sleep(ONE_HOUR - (os.clock() - clock))
		clock = os.clock()
	end

	return true
end

local function setWorldBlocks()
	turtle.setPersistent(true)
	turtle.addWorldBlocks(state.trees)
	return true
end

local function startupCheck()
	Equipper.equipModem('right')
	Equipper.equipLeft(PICKAXE)

	local slots = turtle.getSummedInventory()

	if not slots[SCANNER] or not slots[SENSOR] then
		printError([[
Required:
	* block scanner
	* entity sensor]])
		error('Missing required item')
	end

	if not fs.exists(STARTUP_FILE) then
		Util.writeFile(STARTUP_FILE,
			[[os.sleep(1)
shell.openForegroundTab('superTreefarm.lua')]])
		print('Autorun program created: ' .. STARTUP_FILE)
	end
end

local tasks = {
	{ desc = 'Setting trees',      fn = setTrees           },
	{ desc = 'Startup check',      fn = startupCheck       },
	{ desc = 'Finding home',       fn = findHome           },
	{ desc = 'Set world blocks',   fn = setWorldBlocks     },
	{ desc = 'Creating furnace',   fn = createFurnace      },
	{ desc = 'Chopping',           fn = fell               },
	{ desc = 'Creating chest',     fn = createChests       },
	{ desc = 'Snacking',           fn = eatSaplings        },
	{ desc = 'Making charcoal',    fn = makeCharcoal       },
	{ desc = 'Refueling',          fn = refuel             },
	{ desc = 'Dropping off items', fn = dropOffItems       },
	{ desc = 'Condensing',         fn = turtle.condense    },
	{ desc = 'Returning home',     fn = returnHome         },
	{ desc = 'Sleeping',           fn = updateClock        },
}

turtle.reset()
turtle.set({
	attackPolicy = 'attack',
	digPolicy = 'dig',
	moveCallback = desperateRefuel,
})

local s, m = pcall(function()
	while not turtle.isAborted() do
		print('fuel: ' .. turtle.getFuelLevel())
		for _,task in ipairs(Util.shallowCopy(tasks)) do
			--print(task.desc)
			turtle.setStatus(task.desc)
			turtle.select(1)
			if not task.fn() then
				Util.filterInplace(tasks, function(v) return v.fn ~= task.fn end)
			end
		end
	end
end)

turtle.reset()

if not s and m then
	error(m)
end
