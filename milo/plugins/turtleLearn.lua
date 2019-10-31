local itemDB = require('core.itemDB')
local Milo   = require('milo')
local UI     = require('opus.ui')

local colors = _G.colors
local turtle = _G.turtle

local pages = {
	turtleCraft = UI.WizardPage {
		index = 2,
		validFor = 'Turtle Crafting',
		notice = UI.Text {
			x = 3, y = 2,
			textColor = colors.yellow,
			value = 'Place recipe in turtle',
		},
	},
}

function pages.turtleCraft:validate()
	local recipe, msg = Milo:learnRecipe()

	if recipe then
		local displayName = itemDB:getName(recipe)

		Milo:emptyInventory()

		UI:setPage('listing', {
			filter = displayName,
			message = 'Learned: ' .. displayName,
		})
		return true
	else
		self:emit({ type = 'general_error', message = msg })
	end
end

UI:getPage('learnWizard').wizard:add(pages)
