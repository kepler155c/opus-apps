local Ansi       = require('opus.ansi')
local UI         = require('opus.ui')

local colors     = _G.colors
local device     = _G.device

--[[ Configuration Screen ]]
local template =
[[%sWarning%s

Must an interface for Refined Storage / Applied Energistics.

Add all speed upgrades possible.
]]

local wizardPage = UI.WizardPage {
	title = 'Mass Storage',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = -2,
		value = string.format(template, Ansi.red, Ansi.reset),
	},
}

function wizardPage:isValidFor(node)
	if node.mtype == 'storage' then
		local m = device[node.name]
		return m and m.listAvailableItems
	end
end

function wizardPage:setNode(node)
	self.node = node
end

function wizardPage:validate()
	self.node.adapterType = 'massAdapter'
	return true
end

-- disable until a way is found to transfer between 2 non-transferrable nodes
-- UI:getPage('nodeWizard').wizard:add({ inputChest = wizardPage })
