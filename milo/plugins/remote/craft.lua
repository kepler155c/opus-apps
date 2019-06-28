local Sound   = require('opus.sound')

local args    = { ... }
local context = args[1]

local function learn()
	context:sendRequest({
		request = 'craft',
		slot = 15,
	})
end

context.responseHandlers['craft'] = function(response)
	if response.success then
		Sound.play('entity.item.pickup')
	else
		Sound.play('entity.villager.no')
	end
end

return {
	menuItem = 'Learn recipe',
	callback = function()
		learn()
	end,
}
