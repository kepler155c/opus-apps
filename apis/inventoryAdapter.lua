local Util = require('util')

local Adapter = { }

function Adapter.wrap(args)
	local adapters = {
		--'refinedAdapter',
    --'meAdapter',
    'chestAdapter18',
    'chestAdapter',
  }

	if args and args.side and args.facing and not args.direction then
		args = Util.shallowCopy(args)
		local horz = { top = 'down', bottom = 'up' }
		args.direction = horz[args.side]

		if not args.direction then
			local sides = {
				front = 0,
				back = 2,
				right = 1,
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
			args.direction = icards[(cards[args.facing] + sides[args.side]) % 4]
		end
	end

  for _,adapterType in ipairs(adapters) do
		local adapter = require(adapterType)(args)

		if adapter:isValid() then
			return adapter
		end
	end
end

return Adapter
