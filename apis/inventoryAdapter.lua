local Adapter = { }

function Adapter.wrap(args)
	local adapters = {
		'refinedAdapter',
    'meAdapter',
    'chestAdapter18',
    'chestAdapter',
  }

  for _,adapterType in ipairs(adapters) do
		local adapter = require(adapterType)(args)

		if adapter:isValid() then
			return adapter
		end
	end
end

return Adapter
