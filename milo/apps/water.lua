local os = _G.os
local turtle = _G.turtle

while true do
	turtle.placeDown('minecraft:bucket:0')
	turtle.placeDown('minecraft:glass_bottle:0')
	for k,v in pairs(turtle.getInventory()) do
		if v.name == 'minecraft:concrete_powder' then
			turtle.select(k)
			for _ = 1, v.count do
				turtle.placeDown()
				turtle.digDown()
			end
		end
	end
	os.pullEvent('turtle_inventory')
end
