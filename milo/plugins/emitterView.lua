local Milo    = require('milo')
local UI      = require('opus.ui')
local itemDB  = require('core.itemDB')

local colors  = _G.colors
local device  = _G.device

local wizardPage = UI.WizardPage {
	title = 'Level Emitter',
	index = 2,
	[1] = UI.TextArea {
		x = 2, y = 1,
    height = 2,
		textColor = colors.yellow,
		value = 'Emit a redstone signal if an\nitem amount if over a threshold',
	},
	form = UI.Form {
		x = 1, ex = -1, y = 3, ey = -1,
		manualControls = true,

		itemName = UI.TextEntry {
			formLabel = 'Item', formKey = 'item', formIndex = 1,
			help = 'Item to monitor',
      required = true,
		},
    side = UI.Chooser {
			formLabel = 'Side', formKey = 'side', formIndex = 2,
      width = 10,
      choices = {
        {name = 'Down', value = 'down'},
        {name = 'Up', value = 'up'},
        {name = 'North', value = 'north'},
        {name = 'South', value = 'south'},
        {name = 'West', value = 'west'},
        {name = 'East', value = 'east'},
      },
      required = true,
    },
    amount = UI.TextEntry {
      formLabel = 'Amount', formKey = 'amount', formIndex = 3,
      width = 7,
      transform = 'number',
			help = 'Threshold value',
      required = true,
    },
    signal = UI.Checkbox {
      formLabel = 'Signal', formKey = 'signal', formIndex = 4,
			help = 'Enable redstone signal when over threshold',
    },
		scanItem = UI.Button {
			x = 15, y = 6,
			text = 'Scan item', event = 'scan_turtle',
			help = 'Scan an item from the turtle inventory',
		},
	},
}

function wizardPage:setNode(node)
	self.node = node
	if not self.node.emitter then
		self.node.emitter = {
			signal = { value = true }
		}
	end
	self.form:setValues(self.node.emitter)
end

function wizardPage:validate()
	return self.form:save()
end

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'redstone_integrator' and {
		name = 'Level Emitter',
		value = 'emitter',
		category = 'custom',
		help = 'Emit redstone signals',
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'emitter'
end

function wizardPage:enable()
  Milo:pauseCrafting({ key = 'gridInUse', msg = 'Crafting paused' })
  UI.WizardPage.enable(self)
end
function wizardPage:disable()
  Milo:resumeCrafting({ key = 'gridInUse' })
  UI.WizardPage.disable(self)
end

function wizardPage:eventHandler(event)
	if event.type == 'scan_turtle' then
		local inventory = Milo:getTurtleInventory()
		for _,item in pairs(inventory) do
			self.form.itemName.value = itemDB:makeKey(item)
      break
		end
		self:draw()
		Milo:emptyInventory()
	end
end

UI:getPage('nodeWizard').wizard:add({ emiter = wizardPage })
