local Ansi = require('ansi')
local UI   = require('ui')

local colors = _G.colors
local device = _G.device

local template =
[[%sBrewing stands have the ability to automatically learn recipes.%s

Simply craft potions in the brewing stand as normal except for these conditions.
1. Place item in top slot first.
2. At least 1 bottle must be placed in the first slot.

When finished brewing, the recipe will be available upon refreshing.

Note that you do not need to import items from the brewing stand, this will be done automatically.]]

local brewingStandView = UI.Window {
	title = 'Brewing Stand',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = -2,
		value = string.format(template, Ansi.yellow, Ansi.reset),
	},
}

function brewingStandView:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'minecraft:brewing_stand'and { name = 'Brewing Stand', value = 'brewingStand' }
end

function brewingStandView:isValidFor(node)
	return node.mtype == 'brewingStand'
end

UI:getPage('nodeWizard').wizard:add({ brewingStand = brewingStandView })
