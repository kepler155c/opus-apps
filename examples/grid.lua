local UI = require('opus.ui')

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Shuffle', event = 'shuffle' },
			{ text = 'Clear',   event = 'clear',   },
		}
	},
	grid = UI.ScrollingGrid {
		y = 2, ey = -2,
		values = {
			{ col = 'column1', value = 'value1' },
			{ col = 'column2', value = 'value2' },
			{ col = 'column3', value = 'value3' },
		},
		columns = {
			{ heading = 'HDR1', key = 'col' },
			{ heading = 'HDR2', key = 'value' },
		}
	},
	statusBar = UI.StatusBar { },
}

function page:eventHandler(event)
	if event.type == 'grid_select' then
		self.statusBar:setStatus('Selected: ' .. event.selected.value)

	elseif event.type == 'shuffle' then
		for _,v in pairs(self.grid.values) do
			v.col = 'column' .. math.random(1,3)
		end
		self.grid:update()
		self.grid:draw()

	elseif event.type == 'clear' then
		self.grid:setValues({ })
		self.grid:draw()
	end
	return UI.Page.eventHandler(self, event)
end

UI:setPage(page)
UI:pullEvents()
