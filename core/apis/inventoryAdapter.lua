local Adapter = { }

function Adapter.wrap(args)
	local adapters = {
		'core.refinedAdapter',
		'core.meAdapter18',
    'core.chestAdapter18',

    -- adapters for version 1.7
    'core.meAdapter',
    'core.chestAdapter',
  }

  for _,adapterType in ipairs(adapters) do
		local adapter = require(adapterType)(args)

		if adapter:isValid() then

			-- figure out which direction to push/pull items from an inventory
			-- based on the side the inventory is attached and which way the
			-- turtle/computer is facing
			if args and args.facing and adapter.side and not adapter.direction then
				local horz = { top = 'down', bottom = 'up' }
				adapter.direction = horz[adapter.side]

				if not adapter.direction then
					local sides = {
						front = 0,
						right = 1,
						back = 2,
						left = 3,
					}
		-- pretty sure computer/turtle have sides reversed
					local cards = {
						east = 0,
						south = 1,
						west = 2,
						north = 3,
					}
					local icards = {
						[ 0 ] = 'west',
						[ 1 ] = 'north',
						[ 2 ] = 'east',
						[ 3 ] = 'south',
					}
					adapter.direction = icards[(cards[args.facing] + sides[adapter.side]) % 4]
				end
			end
			return adapter
		end
	end
end

return Adapter
