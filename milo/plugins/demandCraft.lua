local Craft  = require('milo.craft2')
local itemDB = require('core.itemDB')
local Milo   = require('milo')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors = _G.colors

local craftPage = UI.Page {
	titleBar = UI.TitleBar { },
	wizard = UI.Wizard {
		y = 2, ey = -2,
		pages = {
			quantity = UI.WizardPage {
				index = 1,
				text = UI.Text {
					x = 6, y = 3,
					value = 'Quantity',
				},
				count = UI.TextEntry {
					x = 15, y = 3, width = 10,
					limit = 6,
					value = 1,
				},
				ejectText = UI.Text {
					x = 6, y = 4,
					value = 'Eject',
				},
				eject = UI.Chooser {
					x = 15, y = 4, width = 7,
					value = true,
					nochoice = 'No',
					choices = {
						{ name = 'Yes', value = true },
						{ name = 'No', value = false },
					},
				},
			},
			resources = UI.WizardPage {
				index = 2,
				grid = UI.ScrollingGrid {
					y = 2, ey = -2,
					columns = {
						{ heading = 'Name',  key = 'displayName' },
						{ heading = 'Total', key = 'total'      , width = 5 },
						{ heading = 'Used',  key = 'used'       , width = 5 },
						{ heading = 'Need',  key = 'need'       , width = 5 },
					},
					sortColumn = 'displayName',
				},
			},
		},
	},
}

function craftPage:enable(item)
	self.item = item
	self:focusFirst()
	self.titleBar.title = itemDB:getName(item)
--  self.wizard.pages.quantity.eject.value = true
	UI.Page.enable(self)
end

function craftPage.wizard.pages.resources.grid:getDisplayValues(row)
	local function dv(v)
		return v == 0 and '' or Util.toBytes(v)
	end
	row = Util.shallowCopy(row)
	row.total = Util.toBytes(row.total)
	row.used = dv(row.used)
	row.need = dv(row.need)
	return row
end

function craftPage.wizard.pages.resources.grid:getRowTextColor(row, selected)
	if row.need > 0 then
		return colors.orange
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function craftPage.wizard:eventHandler(event)
	if event.type == 'nextView' then
		local count = tonumber(self.pages.quantity.count.value)
		if not count or count <= 0 then
			self.pages.quantity.count.backgroundColor = colors.red
			self.pages.quantity.count:draw()
			return false
		end
		self.pages.quantity.count.backgroundColor = colors.black
	end
	return UI.Wizard.eventHandler(self, event)
end

function craftPage.wizard.pages.resources:enable()
	local items = Milo:listItems()
	local count = tonumber(self.parent.quantity.count.value)
	local recipe = Craft.findRecipe(craftPage.item)
	if recipe then
		local ingredients = Craft.getResourceList4(recipe, items, count)
		for _,v in pairs(ingredients) do
			v.displayName = itemDB:getName(v)
		end
		self.grid:setValues(ingredients)
	else
		self.grid:setValues({ })
	end
	return UI.WizardPage.enable(self)
end

function craftPage:eventHandler(event)
	if event.type == 'cancel' then
		UI:setPreviousPage()

	elseif event.type == 'accept' then
		local item = Util.shallowCopy(self.item)
		item.requested = tonumber(self.wizard.pages.quantity.count.value)
		item.forceCrafting = true
		if self.wizard.pages.quantity.eject.value then
			item.callback = function(request)
				Milo:eject(item, request.requested)
			end
		end
		Milo:requestCrafting(item)
		UI:setPreviousPage()
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:addPage('craft', craftPage)
