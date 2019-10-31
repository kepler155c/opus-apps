local Milo   = require('milo')
local UI     = require('opus.ui')

local turtle = _G.turtle

local learnPage = UI.Page {
	titleBar = UI.TitleBar { title = 'Learn Recipe' },
	wizard = UI.Wizard {
		y = 2, ey = -2,
		pages = {
			general = UI.WizardPage {
				index = 1,
				grid = UI.ScrollingGrid {
					x = 2, ex = -2, y = 2, ey = -2,
					disableHeader = true,
					columns = {
						{ heading = 'Name', key = 'name'},
					},
					sortColumn = 'name',
				},
				accelerators = {
					grid_select = 'nextView',
				},
			},
		},
	},
	notification = UI.Notification { },
}

local general = learnPage.wizard.pages.general

function general:validate()
	Milo:setState('learnType', self.grid:getSelected().value)
	return true
end

function learnPage:enable()
	local t = { }

	for _, page in pairs(self.wizard.pages) do
		if page.validFor then
			t[page.validFor] = {
				name = page.validFor,
				value = page.validFor,
			}
		end
	end
	general.grid:setValues(t)
	general.grid:setSelected('name', Milo:getState('learnType') or '')

	Milo:pauseCrafting({ key = 'gridInUse', msg = 'Crafting paused' })

	self:focusFirst()
	UI.Page.enable(self)
end

function learnPage:disable()
	Milo:resumeCrafting({ key = 'gridInUse' })
	return UI.Page.disable(self)
end

function learnPage.wizard:getPage(index)
	local pages = { }
	table.insert(pages, general)
	local selected = general.grid:getSelected()
	for _, page in pairs(self.pages) do
		if page.validFor and (not selected or selected.value == page.validFor) then
			table.insert(pages, page)
		end
	end
	table.sort(pages, function(a, b)
		return a.index < b.index
	end)

	return pages[index]
end

function learnPage:eventHandler(event)
	if event.type == 'cancel' then
		Milo:emptyInventory()
		UI:setPreviousPage()

	elseif event.type  == 'form_invalid' or event.type == 'general_error' then
		self.notification:error(event.message)
		self:setFocus(event.field)

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:addPage('learnWizard', learnPage)
