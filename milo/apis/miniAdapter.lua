local class   = require('class')
local itemDB  = require('itemDB')
local Util    = require('util')

local device = _G.device

local Adapter = class()

function Adapter:init(args)
  if args.side then
    local inventory = device[args.side]
    if inventory then
      Util.merge(self, inventory)
    end
  end
end

function Adapter:listItems(throttle)
  local cache = { }
  throttle = throttle or Util.throttle()

  for k,v in pairs(self.list()) do
    if v.count > 0 then
      local key = table.concat({ v.name, v.damage, v.nbtHash }, ':')

      local entry = cache[key]
      if not entry then
        local cached = itemDB:get(v)
        if cached then
          cached = Util.shallowCopy(cached)
        else
          cached = self.getItemMeta(k)
          if cached then
            cached = Util.shallowCopy(itemDB:add(cached))
          end
        end
        if cached then
          entry = cached
          entry.count = 0
          cache[key] = entry
        else
          _G._debug('Adapter: failed to get item details')
        end
      end

      if entry then
        entry.count = entry.count + v.count
      end
      throttle()
    end
  end
  itemDB:flush()

  self.cache = cache
end

return Adapter
