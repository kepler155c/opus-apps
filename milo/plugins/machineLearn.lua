local itemDB = require('core.itemDB')
local Milo   = require('milo')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors
local device = _G.device
local turtle = _G.turtle

local context = Milo:getContext()
local machine

local pages = {
	machines = UI.WizardPage {
		index = 2,
		validFor = 'Machine Processing',
		grid = UI.ScrollingGrid {
			y = 2, ey = -2,
			columns = {
				{ heading = 'Name', key = 'displayName' },
			},
			sortColumn = 'displayName',
		},
	},
	confirmation = UI.WizardPage {
		index = 3,
		validFor = 'Machine Processing',
		notice = UI.TextArea {
			x = 2, ex = -2, y = 2, ey = -2,
			backgroundColor = colors.black,
			value =
[[Place items in slots according to the machine's inventory.

Place the result in the last slot of the turtle.

Example: Slot 1 is the top slot in a furnace.]],
		},
	},
}

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
	UI.WizardPage.enable(self)
end

function pages.machines:validate()
	local selected = self.grid:getSelected()
	if not selected then
		self:emit({ type = 'general_error', message = 'No machines configured' })
		return
	end

	machine = device[selected.name]
	if not machine then
		self:emit({type = 'general_error', message = 'Machine not found' })
		return
	end

	if not machine.size then
		self:emit({ type = 'general_error', message = 'Invalid machine' })
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
		self:emit({ type = 'general_error', message = 'Result must be placed in last slot' })
		return
	end

	if Util.empty(inventory) then
		self:emit({ type = 'general_error', message = 'Ingredients not present' })
		return
	end

	for k in pairs(inventory) do
		if k > slotCount then
			self:emit({
				type = 'general_error',
				message = 'Slot ' .. k .. ' is not valid\nThe valid slots are 1 - ' .. machine.size()
			})
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
		if v.count == 1 then
			recipe.ingredients[k] = itemDB:makeKey(v)
		else
			recipe.ingredients[k] = {
				key = itemDB:makeKey(v),
				count = v.count,
			}
		end
	end

	Milo:saveMachineRecipe(recipe, result, machine.name)
	Milo:emptyInventory()

	local displayName = itemDB:getName(result)
	UI:setPage('listing', {
		filter = displayName,
		message = 'Learned: ' .. displayName,
	})

	return true
end

UI:getPage('learnWizard').wizard:add(pages)
