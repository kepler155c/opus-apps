local Ansi = require('opus.ansi')
local UI   = require('opus.ui')

local colors = _G.colors
local device = _G.device

local template =
[[%sBrewing stands have the ability to automatically learn recipes.%s

Simply craft potions in the brewing stand as normal except for these conditions.
1. Place item in top slot FIRST.
2. Place all 3 bottles.

When finished brewing, the recipe will be available upon refreshing.

Note that you do not need to import items from the brewing stand or export blaze powder, this will be done automatically.]]

local wizardPage = UI.WizardPage {
	title = 'Brewing Stand',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = -2,
		value = string.format(template, Ansi.yellow, Ansi.reset),
	},
}

-- Brewing stand shows as Cauldron is Minecraft 1.10
function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and (m.type == 'minecraft:brewing_stand' or m.type == 'Cauldron') and {
		name = 'Brewing Stand',
		value = 'brewingStand',
		category = 'machine',
		help = 'Auto-learning brewing stand',
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'brewingStand'
end

UI:getPage('nodeWizard').wizard:add({ brewingStand = wizardPage })
