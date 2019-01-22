local itemDB  = require('itemDB')
local Milo    = require('milo')

local context = Milo:getContext()
local device  = _G.device

local function craftHandler(user, message, socket)
  local function makeNode()
		local devName = user .. ':inventory'
		local adapter = device[devName]
		if adapter then
			return {
				adapter = adapter,
				name = devName,
			}
		end
	end

  local function craft()
    local slots = {
      [1] = 1, [2] = 2, [3] = 3,
      [5] = 10, [6] = 11, [7] = 12,
      [9] = 19, [10] = 20, [11] = 21,
    }
    local node = makeNode()
    if node then
      for k, v in pairs(slots) do
        node.adapter.pushItems(context.turtleInventory.name, v + message.slot - 1, 1, k)
      end
      local recipe, msg = Milo:learnRecipe()
      if recipe then
        socket:write({
          type = 'craft',
          msg = 'Learned: ' .. itemDB:getName(recipe),
          success = true,
        })
        for k,v in pairs(context.turtleInventory.adapter.list()) do
          node.adapter.pullItems(context.turtleInventory.name, k, v.count)
        end
      else
        socket:write({
          type = 'craft',
          msg = msg,
        })
        for k, v in pairs(slots) do
          node.adapter.pullItems(context.turtleInventory.name, k, 1, v + message.slot - 1)
        end
      end
    end
  end

  Milo:queueRequest({ }, craft)
end

return {
  remoteHandler = { callback = craftHandler, messages = { craft = true } }
}
