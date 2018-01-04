local Util = require('util')

local Adapter = { }

function Adapter.wrap(args, computerInfo)
	local adapters = {
		--'refinedAdapter',
    --'meAdapter',
    'chestAdapter18',
    'chestAdapter',
  }

	if computerInfo then
		args = Util.shallowCopy(args)
		if not args.direction and computerInfo.facing then
			local horz = { top = 'down', bottom = 'up' }
			args.direction = horz[args.wrapSide]

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
				args.direction = icards[(cards[computerInfo.facing] + sides[args.wrapSide]) % 4]
			end
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
