_G.requireInjector(_ENV)

local Event = require('opus.event')
local Util = require('opus.util')
 
local chest = peripheral.wrap('top')

function getOpenChestSlot(stacks)
  for i = 1, chest.getInventorySize() do
    if not stacks[i] then
      return i
    end
  end
end

Event.on('turtle_inventory', function()
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      chest.pullItem('down', i, 1)
      os.sleep(.5)
      local stacks = chest.getAllStacks(false)
      local _,slot = Util.find(stacks, 'qty', 2)
      if slot then
        print('Duplicate')
        chest.pushItem('north', slot, 1)
      else
        print('New Serum')
      end
    end
  end
end)

Event.pullEvents()

