local ChestAdapter   = require('chestAdapter')
local ChestAdapter18 = require('chestAdapter18')
local MEAdapter      = require('meAdapter')

local Adapter = { }

function Adapter.wrap(args)
	local adapter = ChestAdapter18(args)
	if adapter:isValid() then
		return adapter
	end

	adapter = MEAdapter(args)
	if adapter:isValid() then
		return adapter
	end

	adapter = ChestAdapter(args)
	if adapter:isValid() then
		return adapter
	end
end

return Adapter
