local Craft   = require('milo.craft2')
local Milo    = require('milo')
local UI      = require('opus.ui')
local Util    = require('opus.util')

local colors  = _G.colors
local context = Milo:getContext()

local resetTab = UI.Tab {
	tabTitle = 'Reset',
	index = 5,
	backgroundColor = colors.cyan,
	textArea = UI.TextArea {
		y = 2, ey = 6,
		textColor = colors.yellow,
		value = [[                Warning!

		This will clear all setting,
	recipe, and machine for this item.]]
	},
	resetButton = UI.Button {
		x = 17, y = 7,
		event = 'reset',
		text = 'Reset',
		help = 'Clear recipe and all settings',
	},
}

function resetTab:setItem(item)
	self.item = item
end

function resetTab:eventHandler(event)
	if event.type == 'reset' then
		if context.userRecipes[self.item.key] then
			Milo:updateRecipe(self.item.key, nil)
		end

		if context.resources[self.item.key] then
			context.resources[self.item.key] = nil
			Milo:saveResources()
		end

		if Craft.machineLookup[self.item.key] then
			Craft.machineLookup[self.item.key] = nil
			Util.writeTable(Craft.MACHINE_LOOKUP, Craft.machineLookup)
		end

		UI:setPreviousPage()

		return true
	end
end

return { itemTab = resetTab }
