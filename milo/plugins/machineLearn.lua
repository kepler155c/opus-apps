local Craft  = require('turtle.craft')
local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local device = _G.device
local turtle = _G.turtle

local MACHINE_LOOKUP = 'usr/config/machine_crafting.db'

local context = Milo:getContext()

local function getTurtleInventory()
	local introspectionModule = device['plethora:introspection'] or
		error('Introspection module not found')

	local list = { }
	for i = 1,16 do
		list[i] = introspectionModule.getInventory().getItemMeta(i)
	end
	return list
end

local machineLearnWizard = UI.Page {
	titleBar = UI.TitleBar { title = 'Learn a crafting recipe' },
	wizard = UI.Wizard {
		y = 2, ey = -2,
		pages = {
			machine = UI.Window {
				index = 1,
				grid = UI.ScrollingGrid {
					y = 2, ey = -2,
					values = context.config.remoteDefaults,
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

function pages.machine.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.displayName = row.displayName or row.name
	return row
end

function pages.machine:validate()

-- TODO: validation should only be invoked when moving forward (i think)
-- TODO: index number validation in wizard

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
	local inventory = getTurtleInventory()
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

	local key = Milo:uniqueKey(result)

	-- save the recipe
	context.userRecipes[key] = recipe
	Util.writeTable(Milo.RECIPES_FILE, context.userRecipes)

	-- save the machine association
	Craft.machineLookup[key] = machine.name
	Util.writeTable(MACHINE_LOOKUP, Craft.machineLookup)

	Craft.loadRecipes()

	local listingPage = UI:getPage('listing')
	local displayName = itemDB:getName(result)

	listingPage.statusBar.filter:setValue(displayName)
	listingPage.notification:success('Learned: ' .. displayName)
	listingPage.filter = displayName
	listingPage:refresh()
	listingPage.grid:draw()

	return true
end

function machineLearnWizard:enable()
	Milo:pauseCrafting()
	UI.Page.enable(self)
end

function machineLearnWizard:disable()
	Milo:resumeCrafting()
	UI.Page.disable(self)
end

function machineLearnWizard:eventHandler(event)
	if event.type == 'cancel' or event.type == 'accept' then
		turtle.emptyInventory()
		UI:setPage('listing')
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

context.learnTypes['Machine processing'] = machineLearnWizard
