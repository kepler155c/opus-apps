local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device
local turtle = _G.turtle

local context = Milo:getContext()

local machineLearnWizard = UI.Page {
	titleBar = UI.TitleBar { title = 'Select machine' },
	wizard = UI.Wizard {
		y = 2, ey = -2,
		pages = {
			machines = UI.Window {
				index = 1,
				grid = UI.ScrollingGrid {
					y = 2, ey = -2,
					columns = {
						{ heading = 'Name', key = 'displayName' },
					},
					sortColumn = 'displayName',
				},
			},
			confirmation = UI.Window {
				index = 2,
				notice = UI.TextArea {
					x = 2, ex = -2, y = 2, ey = -2,
					backgroundColor = colors.black,
					value =
[[Place items in slots according to the machine's inventory.

Place the result in the last slot of the turtle.

Example: Slot 1 is the top slot in a furnace.]],
				},
			},
		},
	},
	notification = UI.Notification { },
}

local pages = machineLearnWizard.wizard.pages
local machine

function pages.machines.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = row.displayName or row.name
	return row
end

function pages.machines:enable()
	local t = Util.filter(context.storage.nodes, function(node)
		if node.category == 'machine' then
			return node.adapter and node.adapter.online and node.adapter.pushItems
		end
	end)
	self.grid:setValues(t)
	UI.Window.enable(self)
end

function pages.machines:validate()
	local selected = self.grid:getSelected()
	if not selected then
		machineLearnWizard.notification:error('No machines configured')
		return
	end

	machine = device[selected.name]
	if not machine then
		machineLearnWizard.notification:error('Machine not found')
		return
	end

	if not machine.size then
		machineLearnWizard.notification:error('Invalid machine')
		return
	end

	return true
end

function pages.confirmation:validate()
	local inventory = Milo:getTurtleInventory()
	local result    = inventory[16]
	local slotCount = machine.size()

	inventory[16] = nil

	if not result then
		machineLearnWizard.notification:error('Result must be placed in last slot')
		return
	end

	if Util.empty(inventory) then
		machineLearnWizard.notification:error('Ingredients not present')
		return
	end

	for k in pairs(inventory) do
		if k > slotCount then
			machineLearnWizard.notification:error(
				'Slot ' .. k .. ' is not valid\nThe valid slots are 1 - ' .. machine.size())
			return
		end
	end

	-- TODO: maxCount needs to be entered by user ? ie. brewing station can only do 1 at a time

	local recipe = {
		count       = result.count,
		ingredients = { },
		maxCount    = result.maxCount ~= 64 and result.maxCount or nil,
	}

	for k,v in pairs(inventory) do
		recipe.ingredients[k] = Milo:uniqueKey(v)
	end

	Milo:saveMachineRecipe(recipe, result, machine.name)

	local displayName = itemDB:getName(result)

	UI:setPage('listing', {
		filter = displayName,
		message = 'Learned: ' .. displayName,
	})
	return true
end

function machineLearnWizard:disable()
	Milo:resumeCrafting({ key = 'gridInUse' })
	UI.Page.disable(self)
end

function machineLearnWizard:eventHandler(event)
	if event.type == 'cancel' then
		turtle.emptyInventory()
		UI:setPage('listing')
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

context.learnTypes['Machine processing'] = machineLearnWizard
