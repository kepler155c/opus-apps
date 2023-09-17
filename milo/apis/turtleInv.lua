--[[ Emulate a CC:T inventory on the turtle
]]

local TurtleInv = {}

local turtle = _G.turtle

local inventorySize = 16

local localName = "milo_local_name_unset"

function TurtleInv.setLocalName(name)
	localName = name
end

function TurtleInv.size()
	return inventorySize
end

function TurtleInv.list()
	local list = {}
	for slot = 1, inventorySize do
		list[slot] = turtle.getItemDetail(slot)
	end
	return list
end

function TurtleInv.getItemDetail(slot)
	return turtle.getItemDetail(slot, true)
end

function TurtleInv.pullItems(fromName, fromSlot, limit, toSlot)
	return peripheral.call(fromName, "pushItems", localName, fromSlot, limit, toSlot)
end

function TurtleInv.pushItems(toName, fromSlot, limit, toSlot)
	return peripheral.call(toName, "pullItems", localName, fromSlot, limit, toSlot)
end


return TurtleInv
