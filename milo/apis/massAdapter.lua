local class   = require('opus.class')
local itemDB  = require('core.itemDB')
local Mini    = require('milo.miniAdapter')

local os      = _G.os

local Adapter = class(Mini)

function Adapter:init(args)
	Mini.init(self, args)

	self._rawList = self.list

	function self.list()
		-- wait for up to 1 sec until any items that have been inserted
		-- into interface are added to the system
		for _ = 0, 20 do
			if #self._rawList() == 0 then
				break
			end
			os.sleep(0)
		end

		local list = { }
		for _, v in pairs(self.listAvailableItems()) do
			list[itemDB:makeKey(v)] = v
		end
		return list
	end

	function self.getItemMeta(key)
		local item = self.findItem(itemDB:splitKey(key))
		if item and item.getMetadata then
			return item.getMetadata()
		end
	end

	function self.pushItems(target, key, amount, slot)
		local item = self.findItem(itemDB:splitKey(key))
		if item and item.export then
			return item.export(target, amount, slot)
		end
		return 0
	end

	function self.pullItems(target, key, amount, slot)
		_G._syslog({target, key, amount, slot })
		return 0
	end

end

return Adapter
