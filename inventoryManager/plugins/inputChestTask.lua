local InventoryAdapter  = require('inventoryAdapter')
local Lora              = require('lora/lora')

local device = _G.device
local modem  = device.wired_modem

local InputChest = {
	priority = 1,
	adapters = { },
}

function InputChest:init(context)
	for k,v in pairs(context.config.remoteDefaults) do
	  if v.mtype == 'input' then
	    local adapter = InventoryAdapter.wrap({ side = k, direction = modem.getNameLocal() })
	    if adapter then
				table.insert(self.adapters, adapter)
	    end
	  end
	end
end

-- TODO: clear grid

function InputChest:cycle(context)
	for _, adapter in pairs(self.adapters) do
    local list = adapter.list() -- raw list !
    for k,v in pairs(list) do
			adapter:extract(k, v.count, 1)
      context.inventoryAdapter:insert(1, v.count, nil, v)
    end
  end
end

InputChest:init(Lora:getContext())

Lora:registerTask(InputChest)
