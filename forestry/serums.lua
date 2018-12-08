_G.requireInjector(_ENV)

local Event = require('event')
local Util = require('util')
 
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
      local stacks = chest.getAllStacks(false)
      local slot = getOpenChestSlot(stacks)
      chest.pullItemIntoSlot('down', i, 1, slot)
      local serum = chest.getStackInSlot(slot)
      if Util.find(stacks, 'nbt_hash', serum.nbt_hash) then
        print('Duplicate')
        chest.pushItem('north', slot, 1)
      else
        print('New Serum')
      end
    end
  end
 
end)

Event.pullEvents()
