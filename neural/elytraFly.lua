-- original concept: osmarks https://pastebin.com/xEDKdM85

local Sound = require('sound')
local Util  = require('util')

local fs       = _G.fs
local modules  = _G.peripheral.wrap('back')
local os       = _G.os
local parallel = _G.parallel

local STARTUP_FILE = 'usr/autorun/fly.lua'

if not modules.launch or not modules.getMetaOwner then
	print([[Required:
* Kinetic augment
* Entity sensor
* Introspection module]])
	error('missing required item')
end

if not fs.exists(STARTUP_FILE) then
	Util.writeFile(STARTUP_FILE, [[os.sleep(1)
shell.openHiddenTab('elytraFly.lua')]])
	print('Autorun program created: ' .. STARTUP_FILE)
end

local canvas = modules.canvas and modules.canvas()

local function dist(x, y, z)
	return math.sqrt(
		math.pow(x, 2) +
		math.pow(y, 2) +
		math.pow(z, 2))
end

local function display(meta)
	if canvas then
		if not canvas.group then
			canvas.group = canvas.addGroup({ 4, 90 })
			canvas.group.addRectangle(0, 0, 70, 30, 0x00000033)
			canvas.pitch = canvas.group.addText({ 4, 5 }, '') -- , 0x202020FF)
			canvas.pitch.setShadow(true)
			canvas.pitch.setScale(.75)
			canvas.group.addItem({ 5, 30 }, 'minecraft:elytra')
			canvas.group2 = canvas.addGroup({ 80, 10 })
			canvas.group2.addLines(
				{ 0,   0 },
				{ 0, 180 },
				{ 5, 180 },
				{ 5,   0 },
				0x202020FF,
				2)
			canvas.meter = canvas.group2.addRectangle(0, 0, 5, 1)
		end
		local size = math.abs(meta.pitch) -- math.ceil(math.abs(meta.pitch) / 9)
		local y = 0
		local color = 0x202020FF
		if meta.pitch < 0 then
			y = size
			color = 0x808080FF
		end
		canvas.meter.setPosition(0, 90 - y)
		canvas.meter.setSize(5, size)
		canvas.meter.setColor(color)
		canvas.pitch.setText(string.format('Pitch: %s\nMotion Y: %s\nSpeed: %s m/s',
			math.floor(-meta.pitch),
			Util.round(meta.motionY, 2),
			Util.round(dist(meta.motionX, meta.motionY, meta.motionZ) * 20, 2)))
	end
end

local function clearDisplay()
	if canvas and canvas.group then
		canvas.group.remove()
		canvas.group = nil
		canvas.group2.remove()
	end
end

local function run()
	local launchCounter = 0

	while true do
		local meta = modules.getMetaOwner()

		if meta.isOnLadder then
			os.sleep(0.5)

		elseif not meta.isSneaking and meta.isElytraFlying then

			if meta.isInWater then
				display(meta)
				os.sleep(0.5)

			elseif meta.pitch < 0 then -- looking up
				modules.launch(meta.yaw, meta.pitch, -meta.pitch / 22.5)
				Sound.play('entity.bobber.throw', .6)
				display(meta)
				os.sleep(0.1)

			elseif meta.motionY < -0.5 then -- falling fast
				modules.launch(0, 270, math.min(-meta.motionY + 1, 4))
				Sound.play('entity.bat.takeoff')
				display(meta)
				os.sleep(0)

			else
				display(meta)
				os.sleep(0.1)
			end

		elseif meta.isSneaking and not meta.isElytraFlying and meta.pitch == -90 then
			if launchCounter < 2 then
				launchCounter = launchCounter + 1
				Sound.play('block.note.pling', .5)
				os.sleep(0.5)

			else
				Sound.play('entity.bobber.throw', 1)
				modules.launch(0, 270, 4)
				os.sleep(0.2)
			end

		elseif not meta.isSneaking and meta.motionY < -0.8 then
			print('falling...')
			modules.launch(0, 270, -meta.motionY + 1)
			Sound.play('entity.bat.takeoff')
			os.sleep(0)

		elseif meta and meta.isElytraFlying and meta.isSneaking then
			display(meta)
			os.sleep(0.1)

		else
			clearDisplay()
			--display(meta)
			launchCounter = 0
			os.sleep(0.4)
		end
	end
end

parallel.waitForAny(
	function()
		print('\nFlight control initialized')
		print('\nSneak and look straight up for launch')
		print('Sneak to deactivate during flight')
		print('\nPress any key to exit')
		os.pullEvent('char')
	end,
	function()
		while true do
			local _, m = pcall(run)
			if m then
				print(m)
			end
			print('Waiting for 5 seconds before restarting')
			os.sleep(5)
			modules  = _G.peripheral.wrap('back')
			canvas = modules and modules.canvas and modules.canvas()
		end
	end)

clearDisplay()
