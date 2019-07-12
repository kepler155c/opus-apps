local Milo    = require('milo')
local Sound   = require('opus.sound')
local UI      = require('opus.ui')

local colors  = _G.colors
local device  = _G.device
local context = Milo:getContext()

local speakerNode = context.storage:getSingleNode('speaker')
if speakerNode then
	Sound.setVolume(speakerNode.volume)
end

local wizardPage = UI.WizardPage {
	title = 'Speaker',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.Text {
		x = 2, y = 2,
		textColor = colors.yellow,
		value = 'Set the volume for sound effects',
	},
	form = UI.Form {
		x = 2, ex = -2, y = 3, ey = -2,
		manualControls = true,
		volume = UI.Slider {
			formLabel = 'Volume', formKey = 'volume',
			min = 0, max = 1,
			help = 'Volume setting',
		},
		testSound = UI.Button {
			x = 15, y = 3,
			text = 'Test', event = 'test_sound',
			help = 'Test sound volume',
		},
	},
}

function wizardPage:setNode(node)
	self.form:setValues(node)
	if not node.volume then
		self.form.volume = 1
	end
end

function wizardPage:saveNode(node)
	Sound.setVolume(node.volume)
end

function wizardPage:validate()
	return self.form:save()
end

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'speaker' and {
		name = 'Speaker',
		value = 'speaker',
		category = 'custom',
		help = 'Sound effects',
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'speaker'
end

function wizardPage:eventHandler(event)
	if event.type == 'test_sound' then
		local vol = tonumber(self.form.volume.value)
		Sound.play('entity.item.pickup', vol)
	end
end

UI:getPage('nodeWizard').wizard:add({ speaker = wizardPage })
