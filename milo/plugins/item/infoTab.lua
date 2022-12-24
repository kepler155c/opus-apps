local Ansi   = require('opus.ansi')
local UI     = require('opus.ui')

local infoTab = UI.Tab {
	title = 'Info',
	index = 4,
	textArea = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = -2,
	},
}

function infoTab:setItem(item)
	self.item = item
end

function infoTab:draw()
	local item = self.item
	local value =
		string.format('%s%s%s\n%s\n',
			Ansi.orange, item.displayName, Ansi.reset,
			item.name)

	if item.nbt then
		value = value .. item.nbt .. '\n'
	end

	value = value .. string.format('\n%sCount:%s %s',
		Ansi.yellow, Ansi.reset, item.count)

	if item.durability then
		value = value .. string.format('\n%Durability:%s %s',
			Ansi.yellow, Ansi.reset, item.durability)
	end
	
	if item.maxDamage and item.maxDamage > 0 then
		value = value .. string.format(' (max: %s)', item.maxDamage)
	end

	if item.maxCount then
		value = value .. string.format('\n%sStack Size: %s%s',
			Ansi.yellow, Ansi.reset, item.maxCount)
	end

	self.textArea.value = value
	UI.Tab.draw(self)
end

return { itemTab = infoTab }
