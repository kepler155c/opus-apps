_G.requireInjector(_ENV)

local Ansi   = require('ansi')
local UI     = require('ui')
local Util   = require('util')

local colors     = _G.colors
local fs         = _G.fs

local RECIPES_DIR = 'usr/etc/recipes'

local function getRecipeBooks()
	local books = { }

	local files = fs.list(RECIPES_DIR)
	table.sort(files)
	Util.removeByValue(files, 'minecraft.db')

	for _,file in ipairs(files) do
		local path = fs.combine(RECIPES_DIR, file)
		local recipeFile = Util.readTable(path)
		if recipeFile then
			table.insert(books, {
				path = path,
				name = recipeFile.name,
				version = recipeFile.version,
			})
		end
	end

	local config = Util.readTable('usr/config/recipeBooks.db') or { }
	for _, book in pairs(config) do
		local b = Util.find(books, 'path', book)
		if b then
			b.enabled = true
		end
	end

	return books
end

local page = UI.Page {
	info = UI.Window {
		x = 2, ex = -2, y = 2, ey = 5,
		button = UI.Button {
			ex = -1, y = 3, width = 9,
			text = 'Enable',
			event = 'grid_select',
		}
	},
	grid = UI.ScrollingGrid {
		y = 6,
		headerBackgroundColor = colors.black,
		headerTextColor = colors.cyan,
		columns = {
			{ heading = 'Name',    key = 'name'    },
			{ heading = 'Version', key = 'version' },
		},
		values = getRecipeBooks(),
		sortColumn = 'name',
		autospace = true,
	},
	accelerators = {
		q = 'quit',
		space = 'grid_select',
	},
}

function page.info:draw()
	local book = self.parent.grid:getSelected()

	self:clear()
	if book then
		self:setCursorPos(1, 1)
		self:print(
			string.format('Name:    %s%s%s\n', Ansi.yellow, book.name, Ansi.reset))
		self:print(
			string.format('Version: %s%s%s\n', Ansi.yellow, book.version, Ansi.reset))

		self.button.text = book.enabled and 'Disable' or 'Enable'
		self.button:draw()
	end
end

function page.grid:getRowTextColor(row, selected)
	if row.enabled then
		return colors.white
	end
	return selected and colors.lightGray or colors.gray
end

function page:save()
	local t = { }

	for _, book in pairs(self.grid.values) do
		if book.enabled then
			table.insert(t, book.path)
		end
	end

	Util.writeTable('usr/config/recipeBooks.db', t)
end

function page:eventHandler(event)
	if event.type == 'grid_select' then
		local book = self.grid:getSelected()
		book.enabled = not book.enabled
		self.info:draw()
		self.grid:draw()
		self:save()

	elseif event.type == 'grid_focus_row' then
		self.info:draw()

	elseif event.type == 'quit' then
		UI:exitPullEvents()
	end

	UI.Page.eventHandler(self, event)
end

UI:setPage(page)
UI:pullEvents()
