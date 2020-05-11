local Config = require('opus.config')
local Util   = require('opus.util')

local device     = _G.device
local kernel     = _G.kernel
local keyboard   = device.keyboard
local multishell = _ENV.multishell

if not multishell then
	return
end

local config = Config.load('secure', {
	enabled = false,
	timeout = 60,
})

local timer = config.enabled and os.startTimer(config.timeout)

local function buildLockScreen()
	local Event    = require('opus.event')
	local Security = require('opus.security')
	local SHA      = require('opus.crypto.sha2')
	local UI       = require('opus.ui')

	local counter = .1

	local page = UI.Page {
		pass = UI.TextEntry {
			x = 10, ex = -10, y = "50%",
			limit = 32,
			mask = true,
			shadowText = 'password',
			accelerators = {
				enter = 'password',
			},
		},
		notification = UI.Notification(),
	}
	function page:eventHandler(event)
		if event.type == 'password' then

			if self.pass.value and
				#self.pass.value > 0 and
				Security.verifyPassword(SHA.compute(self.pass.value)) then

				UI:quit() -- valid
			else
				self.notification:error('Invalid password', math.max(counter, 2))
				self:sync()
				os.sleep(counter)
				counter = counter * 2

				self.pass:reset()
			end
		else
			UI.Page.eventHandler(self, event)
		end
	end

	Event.onTerminate(function() return false end)

	UI:setPage(page)
	UI:start()

	-- restart lock timer
	timer = os.startTimer(config.timeout)
end

local function showLockScreen()
	timer = nil
	multishell.openTab(_ENV, {
		path = 'sys/apps/Lock.lua',
		fn = buildLockScreen,
		noTerminate = true,
		pinned = true,
		focused = true,
		title = 'Lock',
	})
end

keyboard.addHotkey('control-l', function()
	if timer then
		os.cancelTimer(timer)
		showLockScreen()
	end
end)

kernel.hook({ 'mouse_up', 'mouse_drag', 'key_up', 'mouse_scroll' }, function()
	if timer then
		os.cancelTimer(timer)
		timer = os.startTimer(config.timeout)
	end
end)

kernel.hook('timer', function(_, eventData)
	if timer and eventData[1] == timer then
		showLockScreen()
	end
end)

kernel.hook('config_update', function(_, eventData)
	if eventData[1] == 'secure' then
		Util.merge(config, eventData[2])
		if timer then
			os.cancelTimer(timer)
			timer = nil
		end
		if config.enabled then
			timer = os.startTimer(config.timeout)
		end
	end
end)
