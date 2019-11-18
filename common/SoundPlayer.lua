local Sound = require('opus.sound')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local peripheral = _G.peripheral

if not peripheral.find('speaker') then
	error('No speaker attached')
end

local rawSounds = Util.readLines('packages/common/etc/sounds.txt') or error('Unable to read sounds file')
local sounds = { }
for _, s in pairs(rawSounds) do
	table.insert(sounds, { name = s })
end

UI:configure('SoundPlayer', ...)

local page = UI.Page {
	labelText = UI.Text {
		x = 3, y = 2,
		value = 'Search',
	},
	filter = UI.TextEntry {
		x = 10, y = 2, ex = -3,
		limit = 32,
	},
	grid = UI.ScrollingGrid {
		y = 4,
		columns = {
			{ heading = 'Name', key = 'name' },
		},
		values = sounds,
	},
}

function page:eventHandler(event)
	if event.type == 'grid_select' then
		Sound.play(event.selected.name)

	elseif event.type == 'text_change' then
		if not event.text then
			self.grid.values = sounds
		else
			self.grid.values = { }
			for _,f in pairs(sounds) do
				if string.find(f.name, event.text) then
					table.insert(self.grid.values, f)
				end
			end
		end
		self.grid:update()
		self.grid:setIndex(1)
		self.grid:draw()

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:setPage(page)
UI:pullEvents()
