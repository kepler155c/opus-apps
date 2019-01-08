local Ansi   = require('ansi')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local fs     = _G.fs
local textutils = _G.textutils

local RECIPES_DIR  = 'usr/etc/recipes'
local NAMES_DIR    = 'usr/etc/names'
local RECIPE_BOOKS = 'packages/recipeBook/etc/recipeBook.db'

local db = Util.readTable(RECIPE_BOOKS)

local function getRecipeBooks()
	local books = { }

	if not fs.exists(RECIPES_DIR) then
		fs.makeDir(RECIPES_DIR)
	end

	for _,book in pairs(db) do
		local path = fs.combine(RECIPES_DIR, book.localName .. '.db')
		table.insert(books, {
			recipePath = path,
			namePath = fs.combine(NAMES_DIR, book.localName .. '.db'),
			name = book.name,
			url = book.url,
			version = book.version,
			enabled = fs.exists(path),
		})
	end

	return books
end

local page = UI.Page {
	info = UI.Window {
		x = 2, ex = -2, y = 2, ey = 5,
		button = UI.Button {
			ex = -1, y = 3, width = 10,
			text = 'Enable',
			event = 'grid_select',
		},
		addButton = UI.Button {
			ex = -12, y = 3, width = 10,
			text = 'Add Book',
			event = 'add_book',
		},
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
  add = UI.SlideOut {
    backgroundColor = colors.cyan,
    titleBar = UI.TitleBar {
      title = 'Add a new book',
    },
    form = UI.Form {
      x = 2, ex = -2, y = 2, ey = -1,
      [1] = UI.TextEntry {
        formLabel = 'Name', formKey = 'name',
				shadowText = 'Friendly name',
				limit = 64,
        required = true,
      },
      [2] = UI.TextEntry {
        formLabel = 'Version', formKey = 'version',
        shadowText = 'Mod version',
        limit = 10,
      },
      [3] = UI.TextEntry {
        formLabel = 'URL', formKey = 'url',
				shadowText = 'URL for recipes',
				limit = 128,
        required = true,
      },
      [4] = UI.TextEntry {
        formLabel = 'File name', formKey = 'localName',
				shadowText = 'Short name for saving file',
				limit = 20,
        required = true,
      },
    },
	},
	notification = UI.Notification { },
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
		self.addButton:draw()
	end
end

function page.grid:getRowTextColor(row, selected)
	if row.enabled then
		return colors.white
	end
	return selected and colors.lightGray or colors.gray
end

function page:save(book, enable)
	if enable then
		self.notification:info('Downloading...')
		self:sync()
		local s = pcall(function()
			local recipes = Util.download(book.url)
			if recipes then
				recipes = textutils.unserialize(recipes)
				local names = { }
				for k,v in pairs(recipes.recipes) do
					names[k] = v.displayName
					v.displayName = nil
				end
				Util.writeTable(book.namePath, names)
				Util.writeTable(book.recipePath, recipes)
			end
			book.enabled = true
			self.notification:success('Download complete')
		end)
		if not s then
			self.notification:error('Download failed')
		end
	else
		fs.delete(book.recipePath)
		fs.delete(book.namePath)
		book.enabled = false
	end
end

function page:eventHandler(event)
	if event.type == 'grid_select' then
		local book = self.grid:getSelected()
		self:save(book, not book.enabled)
		self.info:draw()
		self.grid:draw()

	elseif event.type == 'add_book' then
    self.add.form:setValues({ })
    self.add:show()

	elseif event.type == 'form_complete' then
		self.add:hide()
		table.insert(db, self.add.form.values)
		Util.writeTable(RECIPE_BOOKS, db)
		self.grid:setValues(getRecipeBooks())
		self.grid:draw()

  elseif event.type == 'form_cancel' then
    self.add:hide()

	elseif event.type == 'grid_focus_row' then
		self.info:draw()

	elseif event.type == 'quit' then
		UI:exitPullEvents()
	end

	UI.Page.eventHandler(self, event)
end

UI:setPage(page)
UI:pullEvents()
