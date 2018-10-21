local Lora = require('lora/lora')

local LimitTask = {
	priority = 10,
}

function LimitTask:init(context)
	for k,v in pairs(context.config.remoteDefaults) do
	  if v.mtype == 'trashcan' then
			self.trashcan = k
			break
	  end
	end
end

function LimitTask:cycle(context)
	if not self.trashcan then
		return
	end

  for _,res in pairs(context.resources) do
		if res.limit then
	    local item = Lora:getItemWithQty(res, res.ignoreDamage, res.ignoreNbtHash)
	    if item and item.count > res.limit then
	      context.inventoryAdapter:provide(
	        { name = item.name, damage = item.damage, nbtHash = item.nbtHash },
	        item.count - res.limit,
	        nil,
	        self.trashcan)
	    end
	  end
  end
end

LimitTask:init(Lora:getContext())
Lora:registerTask(LimitTask)
