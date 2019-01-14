local Ansi   = require('ansi')
local UI     = require('ui')

local colors = _G.colors

local infoTab = UI.Window {
	tabTitle = 'Info',
	index = 4,
	backgroundColor = colors.cyan,
	textArea = UI.TextArea {
		x = 2, ex = -2, y = 2,
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

	if item.nbtHash then
		value = value .. item.nbtHash .. '\n'
	end

	value = value .. string.format('\n%sDamage:%s %s',
		Ansi.yellow, Ansi.reset, item.damage)

	if item.maxDamage and item.maxDamage > 0 then
		value = value .. string.format(' (max: %s)', item.maxDamage)
	end

	if item.maxCount then
		value = value .. string.format('\n%sStack Size: %s%s',
			Ansi.yellow, Ansi.reset, item.maxCount)
	end

	self.textArea.value = value
	UI.Window.draw(self)
end

return { itemTab = infoTab }
