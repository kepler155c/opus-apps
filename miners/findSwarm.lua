local Event   = require('opus.event')
local GPS     = require('opus.gps')
local Point   = require('opus.point')
local Sound   = require('opus.sound')
local Swarm   = require('core.swarm')
local Util    = require('opus.util')

local os         = _G.os
local peripheral = _G.peripheral

local COLUMNS = 4

local gpt = GPS.getPoint() or error('GPS not found')
local scanner = peripheral.find('neuralInterface')
if not scanner or not scanner.scan then
	error('Plethora scanner must be equipped')
end

local paused, abort
local chunkIndex = 0
local swarm = Swarm()
local blocks = Util.transpose({
	'minecraft:chest',
--  'minecraft:mob_spawner',
	'quark:crystal',
	'minecraft:mossy_cobblestone'
})
local locations = { }

gpt.x = gpt.x + 1

local function getLocations()
	local y = gpt.y - 8
	while y > 5 do
		table.insert(locations, y)
		y = y - 16
	end
	if y > 0 then
		table.insert(locations, 5)
	end
end

for _, b in pairs(scanner.scan()) do
	if b.name == 'computercraft:turtle_advanced' or
		 b.name == 'computercraft:turtle' then

		local v = scanner.getBlockMeta(b.x, b.y, b.z)
		if v and v.computer then
			if not v.computer.isOn then
				print('Powered off: ' .. v.computer.id)
			elseif v.turtle.fuel < 100 then
				print('not enough fuel: ' .. v.computer.id)
			else
				swarm:add(v.computer.id, {
					point = {
						x = gpt.x + b.x,
						y = gpt.y + b.y,
						z = gpt.z + b.z,
						heading = Point.facings[v.state.facing].heading,
					},
					index = Util.size(swarm.pool),
				})
			end
		end
	end
end

local function getNextPoint(member)
	local z = math.floor(chunkIndex / COLUMNS)
	local x = chunkIndex % COLUMNS

	chunkIndex = chunkIndex + 1

	while paused do
		if abort then
			return
		end
		os.sleep(3)
	end

	return {
		x = gpt.x + (x * 16),
		y = gpt.y + member.index,
		z = gpt.z + (z * 16)
	}
end

local function run(member)
	local turtle = member.turtle

	if not turtle.has('plethora:module:2') then
		error('missing scanner')
	end
	turtle.reset()
	turtle.set({
		attackPolicy = 'attack',
		digPolicy = 'turtleSafe',
		movementStrategy = 'goto',
		point = member.point,
	})
	turtle.select(1)
	local swapSide = turtle.isEquipped('modem') == 'right' and 'left' or 'right'

	repeat
		local pt = getNextPoint(member)
		if pt then
			turtle.set({ status = 'Relocating' })
			turtle.go({ y = pt.y })
			local c = os.clock()
			while not turtle.go(pt) do
				if abort then
					break
				end
				os.sleep(.5)
				if os.clock() - c > 3 then
					Sound.play('entity.villager.no')
					print('stuck: ' .. member.id)
					turtle.set({ status = 'Stuck' })
				end
			end
			turtle.set({ status = 'Boring' })

			for _, v in ipairs(locations) do
				if abort then
					break
				end
				turtle.go({ y = v })
				turtle.equip(swapSide, 'plethora:module:2')
				local found = turtle.scan(blocks)
				turtle.equip(swapSide, 'minecraft:diamond_pickaxe')
				if Util.size(found) > 0 then
					paused = true
					local _, b = next(found)
					print(string.format('%s:%s:%s %s', b.x, b.y, b.z, b.name))
					print('press r to continue')
					for _ = 1, 3 do
						Sound.play('block.note.pling')
						os.sleep(.3)
					end
				end
			end
			turtle.go({ y = pt.y })
		end
	until abort

	turtle.set({ status = 'Aborting' })
	turtle.go({ y = gpt.y + member.index })
	turtle.go({ x = gpt.x, y = gpt.y + member.index, z = gpt.z })

	repeat until turtle.go({ y = gpt.y })
	turtle.set({ status = 'idle' })
end

function swarm:onRemove(member, success, message)
	if not success then
		Sound.play('entity.villager.no')
		print('Removed from swarm: ' .. member.id)
		_G.printError(message)
	end

	print('Turtles: ' .. Util.size(self.pool))
	if Util.size(self.pool) == 0 then
		Event.exitPullEvents()
	end
end

print('press a to abort, r to resume')
Event.on('char', function(_, k)
	if k == 'r' then
		print('Resuming')
		paused = false
	elseif k == 'a' then
		gpt = GPS.getPoint()
		print('Aborting')
		abort = true
	end
end)

getLocations()

Util.print('Found %s turtles', Util.size(swarm.pool))
swarm:run(run)

Event.pullEvents()
