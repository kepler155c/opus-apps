local Milo = require('milo')
local Util = require('util')

local Autocraft = {
  name = 'autocraft',
  priority = 100,
}

-- TODO: fix/test
function Autocraft:cycle(context)
  local list = { }

  for _,res in pairs(context.resources) do
    if res.auto then
      res = Util.shallowCopy(res)
      res.count = 256
      list[Milo:uniqueKey(res)] = res
    end
  end

  if not Util.empty(list) then
    Milo:craftItems(list)
  end
end

Milo:registerTask(Autocraft)
