if not _G.turtle and not _G.commands then
	error('Must be run on a turtle or a command computer')
end

local Adapter   = require('core.inventoryAdapter')
local Event     = require('opus.event')
local GPS       = require('opus.gps')
local itemDB    = require('core.itemDB')
local Schematic = require('builder.schematic')
local TableDB   = require('core.tableDB')
local UI        = require('opus.ui')
local Util      = require('opus.util')

local colors     = _G.colors
local fs         = _G.fs

local BUILDER_DIR = 'usr/builder'

local substitutionPage
local Builder

if _G.commands then
	Builder = require('builder.commands')
else
	Builder = require('builder.turtle')
end

Builder = Builder()
Builder.schematic = Schematic()

local function convertSingleBack(item)
	if item then
		item.id = item.name
		item.dmg = item.damage
		item.qty = item.count
		item.max_size = item.maxCount
		item.display_name = item.displayName
	end
	return item
end

local function convertBack(t)
	for _,v in pairs(t) do
		convertSingleBack(v)
	end
	return t
end

--[[-- SubDB --]]--
local subDB = TableDB({
	fileName = fs.combine(BUILDER_DIR, 'sub.db'),
})

function subDB:load()
	if fs.exists(self.fileName) then
		TableDB.load(self)
	elseif not Builder.isCommandComputer then
		self:seedDB()
	end
end

function subDB:seedDB()
	self.data = {
		[ "minecraft:redstone_wire:0"        ] = "minecraft:redstone:0",
		[ "minecraft:wall_sign:0"            ] = "minecraft:sign:0",
		[ "minecraft:standing_sign:0"        ] = "minecraft:sign:0",
		[ "minecraft:potatoes:0"             ] = "minecraft:potato:0",
		[ "minecraft:unlit_redstone_torch:0" ] = "minecraft:redstone_torch:0",
		[ "minecraft:powered_repeater:0"     ] = "minecraft:repeater:0",
		[ "minecraft:unpowered_repeater:0"   ] = "minecraft:repeater:0",
		[ "minecraft:carrots:0"              ] = "minecraft:carrot:0",
		[ "minecraft:cocoa:0"                ] = "minecraft:dye:3",
		[ "minecraft:unpowered_comparator:0" ] = "minecraft:comparator:0",
		[ "minecraft:powered_comparator:0"   ] = "minecraft:comparator:0",
		[ "minecraft:piston_head:0"          ] = "minecraft:air:0",
		[ "minecraft:piston_extension:0"     ] = "minecraft:air:0",
		[ "minecraft:portal:0"               ] = "minecraft:air:0",
		[ "minecraft:double_wooden_slab:0"   ] = "minecraft:planks:0",
		[ "minecraft:double_wooden_slab:1"   ] = "minecraft:planks:1",
		[ "minecraft:double_wooden_slab:2"   ] = "minecraft:planks:2",
		[ "minecraft:double_wooden_slab:3"   ] = "minecraft:planks:3",
		[ "minecraft:double_wooden_slab:4"   ] = "minecraft:planks:4",
		[ "minecraft:double_wooden_slab:5"   ] = "minecraft:planks:5",
		[ "minecraft:lit_redstone_lamp:0"    ] = "minecraft:redstone_lamp:0",
		[ "minecraft:double_stone_slab:1"    ] = "minecraft:sandstone:0",
		[ "minecraft:double_stone_slab:2"    ] = "minecraft:planks:0",
		[ "minecraft:double_stone_slab:3"    ] = "minecraft:cobblestone:0",
		[ "minecraft:double_stone_slab:4"    ] = "minecraft:brick_block:0",
		[ "minecraft:double_stone_slab:5"    ] = "minecraft:stonebrick:0",
		[ "minecraft:double_stone_slab:6"    ] = "minecraft:nether_brick:0",
		[ "minecraft:double_stone_slab:7"    ] = "minecraft:quartz_block:0",
		[ "minecraft:double_stone_slab:9"    ] = "minecraft:sandstone:2",
		[ "minecraft:double_stone_slab2:0"   ] = "minecraft:sandstone:0",
		[ "minecraft:stone_slab:2"           ] = "minecraft:wooden_slab:0",
		[ "minecraft:wheat:0"                ] = "minecraft:wheat_seeds:0",
		[ "minecraft:flowing_water:0"        ] = "minecraft:air:0",
		[ "minecraft:lit_furnace:0"          ] = "minecraft:furnace:0",
		[ "minecraft:wall_banner:0"          ] = "minecraft:banner:0",
		[ "minecraft:standing_banner:0"      ] = "minecraft:banner:0",
		[ "minecraft:tripwire:0"             ] = "minecraft:string:0",
		[ "minecraft:pumpkin_stem:0"         ] = "minecraft:pumpkin_seeds:0",
	}
	self.dirty = true
	self:flush()
end

function subDB:add(s)
	TableDB.add(self, { s.id, s.dmg }, table.concat({ s.sid, s.sdmg }, ':'))
	self:flush()
end

function subDB:remove(s)
	-- TODO: tableDB.remove should take table key
	TableDB.remove(self, s.id .. ':' .. s.dmg)
	self:flush()
end

function subDB:extract(s)
	local id, dmg = s:match('(.+):(%d+)')
	return id, tonumber(dmg)
end

function subDB:getSubstitutedItem(id, dmg)
	local sub = TableDB.get(self, { id, dmg })
	if sub then
		id, dmg = self:extract(sub)
	end
	return { id = id, dmg = dmg }
end

function subDB:lookupBlocksForSub(sid, sdmg)
	local t = { }
	for k,v in pairs(self.data) do
		local id, dmg = self:extract(v)
		if id == sid and dmg == sdmg then
			id, dmg = self:extract(k)
			t[k] = { id = id, dmg = dmg, sid = sid, sdmg = sdmg }
		end
	end
	return t
end

--[[-- blankPage --]]--
local blankPage = UI.Page()
function blankPage:draw()
	self:clear(colors.black)
	self:setCursorPos(1, 1)
end

function blankPage:enable()
	self:sync()
	UI.Page.enable(self)
end

--[[-- selectSubstitutionPage --]]--
local selectSubstitutionPage = UI.Page({
	titleBar = UI.TitleBar({
		title = 'Select a substitution',
		previousPage = 'listing'
	}),
	grid = UI.ScrollingGrid({
		columns = {
			{ heading = 'id',  key = 'id'  },
			{ heading = 'dmg', key = 'dmg' },
		},
		sortColumn = 'id',
		height = UI.term.height-1,
		autospace = true,
		y = 2,
	}),
})

function selectSubstitutionPage:enable()
	self.grid:adjustWidth()
	self.grid:setIndex(1)
	UI.Page.enable(self)
end

function selectSubstitutionPage:eventHandler(event)
	if event.type == 'grid_select' then
		substitutionPage.sub = event.selected
		UI:setPage(substitutionPage)
	elseif event.type == 'key' and event.key == 'q' then
		UI:setPreviousPage()
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

--[[-- substitutionPage --]]--
substitutionPage = UI.Page {
	titleBar = UI.TitleBar {
		previousPage = true,
		title = 'Substitute a block'
	},
	menuBar = UI.MenuBar {
		y = 2,
		buttons = {
			{ text = 'Accept', event = 'accept', help = 'Accept'              },
			{ text = 'Revert', event = 'revert', help = 'Restore to original' },
			{ text = 'Air',    event = 'air',    help = 'Air'                 },
		},
	},
	info = UI.Window { y = 4, width = UI.term.width, height = 3 },
	grid = UI.ScrollingGrid {
		columns = {
			{ heading = 'Name', key = 'display_name', width = UI.term.width-9 },
			{ heading = 'Qty',  key = 'fQty', width = 5               },
		},
		sortColumn = 'display_name',
		height = UI.term.height-7,
		y = 7,
	},
	throttle = UI.Throttle { },
	statusBar = UI.StatusBar { }
}

substitutionPage.menuBar:add({
	filterLabel = UI.Text({
		value = 'Search',
		x = UI.term.width-14,
	}),
	filter = UI.TextEntry({
		x = UI.term.width-7,
		width = 7,
	})
})

function substitutionPage.info:draw()
	local sub = self.parent.sub
	local inName = itemDB:getName({ name = sub.id, damage = sub.dmg })
	local outName = ''
	if sub.sid then
		outName = itemDB:getName({ name = sub.sid, damage = sub.sdmg })
	end

	self:clear()
	self:print(' Replace ' .. inName .. '\n' .. ' With    ' .. outName)
end

function substitutionPage:enable()
	self.allItems = convertBack(Builder.itemAdapter:refresh())
	self.grid.values = self.allItems
	for _,item in pairs(self.grid.values) do
		item.key = item.id .. ':' .. item.dmg
		item.lname = string.lower(item.display_name)
		item.fQty = Util.toBytes(item.qty)
	end
	self.grid:update()

	self.menuBar.filter:reset()
	self:setFocus(self.menuBar.filter)
	UI.Page.enable(self)
end

function substitutionPage:applySubstitute(id, dmg)
	self.sub.sid = id
	self.sub.sdmg = dmg
end

function substitutionPage:eventHandler(event)
	if event.type == 'grid_focus_row' then
		local s = string.format('%s:%d',
			event.selected.id,
			event.selected.dmg)

		self.statusBar:setStatus(s)
		self.statusBar:draw()

	elseif event.type == 'grid_select' then
		self:applySubstitute(event.selected.id, event.selected.dmg)
		self.info:draw()

	elseif event.type == 'text_change' then
		local text = event.text or ''
		if #text == 0 then
			self.grid.values = self.allItems
		else
			self.grid.values = { }
			for _,item in pairs(self.allItems) do
				if string.find(item.lname, text) then
					table.insert(self.grid.values, item)
				end
			end
		end
		self.grid:update()
		self.grid:setIndex(1)
		self.grid:draw()

	elseif event.type == 'accept' or event.type == 'air' or event.type == 'revert' then
		self.statusBar:setStatus('Saving changes...')
		self.statusBar:draw()
		self:sync()

		if event.type == 'air' then
			self:applySubstitute('minecraft:air', 0)
		end

		if event.type == 'revert' then
			subDB:remove(self.sub)
		elseif not self.sub.sid then
			self.statusBar:setStatus('Select a substition')
			self.statusBar:draw()
			return UI.Page.eventHandler(self, event)
		else
			subDB:add(self.sub)
		end

		self.throttle:enable()
		Builder:reloadSchematic(function() self.throttle:update() end)
		self.throttle:disable()
		UI:setPage('listing')

	elseif event.type == 'cancel' then
		UI:setPreviousPage()
	end

	return UI.Page.eventHandler(self, event)
end

--[[-- ListingPage --]]--
local listingPage = UI.Page({
	titleBar = UI.TitleBar({
		title = 'Supply List',
		previousPage = 'start'
	}),
	menuBar = UI.MenuBar({
		y = 2,
		buttons = {
			{ text = 'Craft',      event = 'craft',   help = 'Request crafting'      },
			{ text = 'Refresh',    event = 'refresh', help = 'Refresh inventory'     },
			{ text = 'Toggle',     event = 'toggle',  help = 'Toggles needed blocks' },
			{ text = 'Substitute', event = 'edit',    help = 'Substitute a block'    },
		}
	}),
	grid = UI.ScrollingGrid({
		columns = {
			{ heading = 'Name', key = 'display_name', width = UI.term.width - 14 },
			{ heading = 'Need', key = 'need', width = 5                  },
			{ heading = 'Have', key = 'qty',  width = 5                  },
		},
		sortColumn = 'display_name',
		y = 3,
		height = UI.term.height-3,
		help = 'Set a block type or pick a substitute block'
	}),
	accelerators = {
		q = 'menu',
		c = 'craft',
		r = 'refresh',
		t = 'toggle',
	},
	statusBar = UI.StatusBar(),
	fullList = true
})

function listingPage:enable(throttle)
	listingPage:refresh(throttle)
	UI.Page.enable(self)
end

function listingPage:eventHandler(event)
	if event.type == 'craft' then
		local s = self.grid:getSelected()
		local item = convertSingleBack(Builder.itemAdapter:getItemInfo({
			name = s.id,
			damage = s.dmg,
			nbtHash = s.nbt_hash,
		}))
		if item and item.is_craftable then
			local qty = math.max(0, s.need - item.qty)

			if item and Builder.itemAdapter.craftItems then
				Builder.itemAdapter:craftItems({{ name = s.id, damage = s.dmg, nbtHash = s.nbt_hash, count = qty }})
				local name = s.display_name or s.id
				self.statusBar:timedStatus('Requested ' .. qty .. ' ' .. name, 3)
			end
		else
			self.statusBar:timedStatus('Unable to craft')
		end

	 elseif event.type == 'grid_focus_row' then
		self.statusBar:setStatus(event.selected.id .. ':' .. event.selected.dmg)
		self.statusBar:draw()

	elseif event.type == 'refresh' then
		self:refresh()
		self:draw()
		self.statusBar:timedStatus('Refreshed ', 3)

	elseif event.type == 'toggle' then
		self.fullList = not self.fullList
		self:refresh()
		self:draw()

	elseif event.type == 'menu' then
		UI:setPage('start')

	elseif event.type == 'edit' or event.type == 'grid_select' then
		self:manageBlock(self.grid:getSelected())

	elseif event.type == 'focus_change' then
		if event.focused.help then
			self.statusBar:timedStatus(event.focused.help, 3)
		end
	end

	return UI.Page.eventHandler(self, event)
end

function listingPage.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.need = Util.toBytes(row.need)
	row.qty = Util.toBytes(row.qty)
	return row
end

function listingPage.grid:getRowTextColor(row, selected)
	if row.is_craftable then
		return colors.yellow
	end
	return UI.Grid:getRowTextColor(row, selected)
end

function listingPage:refresh(throttle)
	local supplyList = Builder:getBlockCounts()

	Builder.itemAdapter:refresh(throttle)

	for _,b in pairs(supplyList) do
		if b.need > 0 then
			local item = convertSingleBack(Builder.itemAdapter:getItemInfo({
				name = b.id,
				damage = b.dmg,
				nbtHash = b.nbt_hash,
			}))

			if item then
				b.display_name = item.display_name
				b.qty = item.qty
				b.is_craftable = item.is_craftable
			else
				b.display_name = itemDB:getName({ name = b.id, damage = b.dmg })
			end
		end
		if throttle then
			throttle()
		end
	end

	if self.fullList then
		self.grid:setValues(supplyList)
	else
		local t = {}
		for _,b in pairs(supplyList) do
			if self.fullList or b.qty < b.need then
				table.insert(t, b)
			end
		end
		self.grid:setValues(t)
	end
	self.grid:setIndex(1)
end

function listingPage:manageBlock(selected)
	local substitutes = subDB:lookupBlocksForSub(selected.id, selected.dmg)

	if Util.empty(substitutes) then
		substitutionPage.sub = { id = selected.id, dmg = selected.dmg }
		UI:setPage(substitutionPage)
	elseif Util.size(substitutes) == 1 then
		local _,sub = next(substitutes)
		substitutionPage.sub = sub
		UI:setPage(substitutionPage)
	else
		selectSubstitutionPage.selected = selected
		selectSubstitutionPage.grid:setValues(substitutes)
		UI:setPage(selectSubstitutionPage)
	end
end

--[[-- startPage --]]--
local wy = 2
local my = 3

if UI.term.width < 30 then
	wy = 9
	my = 2
end

local startPage = UI.Page {
	window = UI.Window {
		x = UI.term.width-16,
		y = wy,
		width = 16,
		height = 9,
		backgroundColor = colors.gray,
		grid = UI.Grid {
			columns = {
				{ heading = 'Name',  key = 'name',  width = 6 },
				{ heading = 'Value', key = 'value', width = 7 },
			},
			disableHeader = true,
			x = 1,
			y = 2,
			width = 16,
			height = 9,
			inactive = true,
			backgroundColor = colors.gray
		},
	},
	menu = UI.Menu {
		x = 2,
		y = my,
		height = 7,
		backgroundColor = UI.Page.defaults.backgroundColor,
		menuItems = {
			{ prompt = 'Set starting level', event = 'startLevel' },
			{ prompt = 'Set starting block', event = 'startBlock' },
			{ prompt = 'Set starting point', event = 'startPoint' },
			{ prompt = 'Supply list',        event = 'assignBlocks' },
			{ prompt = 'Toggle mode',        event = 'toggleMode' },
			{ prompt = 'Begin',              event = 'begin' },
			{ prompt = 'Quit',               event = 'quit' }
		}
	},
	startLevel = UI.Dialog {
		title = 'Enter Starting Level',
		height = 7,
		form = UI.Form {
			y = 3, x = 2, height = 4,
			event = 'setStartLevel',
			cancelEvent = 'slide_hide',
			text = UI.Text {
				x = 5, y = 1, width = 10,
				textColor = colors.gray,
			},
			textEntry = UI.TextEntry {
				formKey = 'level',
				x = 15, y = 1, width = 7,
			},
		},
		statusBar = UI.StatusBar(),
	},
	startBlock = UI.Dialog {
		title = 'Enter Block Number',
		height = 7,
		form = UI.Form {
			y = 3, x = 2, height = 4,
			event = 'setStartBlock',
			cancelEvent = 'slide_hide',
			text = UI.Text {
				x = 2, y = 1, width = 13,
				textColor = colors.gray,
			},
			textEntry = UI.TextEntry {
				x = 16, y = 1,
				width = 10, limit = 8,
			},
		},
		statusBar = UI.StatusBar(),
	},
	startPoint = UI.Dialog {
		title = 'Set starting point',
		height = 11,
		form = UI.Form {
			y = 2, x = 2, ey = -2,
			cancelEvent = 'slide_hide',
			text1 = UI.Text {
				x = 1, y = 2, value = 'Turtle location' },
			xLoc = UI.TextEntry {
				x = 1, y = 3, formKey = 'x', width = 7, limit = 16, shadowText = 'x', required = true },
			yLoc = UI.TextEntry {
				x = 9, y = 3, formKey = 'y', width = 7, limit = 16, shadowText = 'y', required = true },
			zLoc = UI.TextEntry {
				x = 17, y = 3, formKey = 'z', width = 7, limit = 16, shadowText = 'z', required = true },
			text2 = UI.Text {
				x = 1, y = 5, value = 'Starting Point' },
			xrLoc = UI.TextEntry {
				x = 1, y = 6, formKey = 'rx', width = 7, limit = 16, shadowText = 'x', required = true },
			yrLoc = UI.TextEntry {
				x = 9, y = 6, formKey = 'ry', width = 7, limit = 16, shadowText = 'y', required = true },
			zrLoc = UI.TextEntry {
				x = 17, y = 6, formKey = 'rz', width = 7, limit = 16, shadowText = 'z', required = true },
			revert = UI.Button {
				x = 1, y = -2, text = 'Revert', event = 'revert' },
			accelerators = {
				form_cancel = 'slide_hide',
			},
		},
		statusBar = UI.StatusBar({ values = 'Optional start point'}),
	},
	throttle = UI.Throttle { },
	accelerators = {
		x = 'test',
		[ 'control-q' ] = 'quit'
	}
}

function startPage:draw()
	local t = {
		{ name = 'mode', value = Builder.mode },
		{ name = 'start', value = Builder.index },
		{ name = 'blocks', value = #Builder.schematic.blocks },
		{ name = 'length', value = Builder.schematic.length },
		{ name = 'width', value = Builder.schematic.width },
		{ name = 'height', value = Builder.schematic.height },
	}

	self.window.grid:setValues(t)
	UI.Page.draw(self)
end

function startPage:enable()
	self:setFocus(self.menu)
	UI.Page.enable(self)
end

function startPage.startPoint:eventHandler(event)
	if event.type == 'form_complete' then
		for k,v in pairs(event.values) do
			Builder.loc[k] = tonumber(v)
		end
		Builder:saveProgress(Builder.index)
		self:hide()
	elseif event.type == 'revert' then
		Builder.loc = { }
		Builder:saveProgress(Builder.index)
		self:hide()
	elseif event.type == 'form_invalid' then
		self.statusBar:setStatus(event.message)
	elseif event.type == 'form_cancel' or event.type == 'cancel' then
		self:hide()
	else
		return UI.Dialog.eventHandler(self, event)
	end
	return true
end

function startPage:eventHandler(event)
	if event.type == 'startLevel' then
		self.startLevel.form.text.value = '0 - ' .. Builder.schematic.height
		self.startLevel:show()

	elseif event.type == 'setStartLevel' then
		local l = tonumber(self.startLevel.form.textEntry.value)
		if l and l < Builder.schematic.height and l >= 0 then
			for k,v in pairs(Builder.schematic.blocks) do
				if v.y >= l then
					Builder.index = k
					Builder:saveProgress(Builder.index)
					break
				end
			end
			self.startLevel:hide()
			self:draw()
		else
			self.startLevel.statusBar:setStatus('Invalid start level')
		end

	elseif event.type == 'startBlock' then
		self.startBlock.form.text.value = '1 - ' .. #Builder.schematic.blocks
		self.startBlock.form.textEntry.value = tostring(Builder.index)
		self.startBlock:show()

	elseif event.type == 'setStartBlock' then
		local bn = tonumber(self.startBlock.form.textEntry.value)
		if bn and bn < #Builder.schematic.blocks and bn >= 0 then
			Builder.index = bn
			Builder:saveProgress(Builder.index)
			self.startBlock:hide()
			self:draw()
		else
			self.startLevel.statusBar:setStatus('Invalid start block')
		end

	elseif event.type == 'startPoint' then
		local loc = Util.shallowCopy(Builder.loc)
		if not loc.x then
			if _G.turtle then
				local pt = GPS.getPoint()
				if pt then
					loc.x = pt.x
					loc.y = pt.y
					loc.z = pt.z
				end
			elseif _G.commands then
				loc.x, loc.y, loc.z = _G.commands.getBlockPosition()
			end
		end

		self.startPoint.form:setValues(loc)
		self.startPoint:show()

	elseif event.type == 'assignBlocks' then
		-- this might be an approximation of the blocks needed
		-- as the current level's route may or may not have been
		-- computed
		Builder:dumpInventory()
		UI:setPage('listing', function() self.throttle:update() end)
		self.throttle:disable()

	elseif event.type == 'toggleMode' then
		if Builder.mode == 'build' then
			if Builder.index == 1 then
				Builder.index = #Builder.schematic.blocks
			end
			Builder.mode = 'destroy'
		else
			if Builder.index == #Builder.schematic.blocks then
				Builder.index = 1
			end
			Builder.mode = 'build'
		end
		self:draw()

	elseif event.type == 'begin' then
		UI:setPage('blank')
		self:sync()

		print('Reloading schematic')
		Builder:reloadSchematic(Util.throttle())
		Builder:begin()

	elseif event.type == 'quit' then
		UI:quit()
	end

	return UI.Page.eventHandler(self, event)
end

--[[-- startup logic --]]--
local args = {...}
if #args < 1 then
	error('supply file name or URL')
end

Builder.itemAdapter = Adapter.wrap({ side = 'bottom', direction = 'up' })
if not Builder.itemAdapter then
	error('A chest or ME interface must be below turtle')
end

subDB:load()

UI.term:reset()
print('Loading schematic')
Builder.schematic:load(args[1])
print('Substituting blocks')

Builder.subDB = subDB
Builder:substituteBlocks(Util.throttle())

if not fs.exists(BUILDER_DIR) then
	fs.makeDir(BUILDER_DIR)
end

Builder:loadProgress(Builder.schematic.filename .. '.progress')

Event.on('build', function()
	Builder:build()
end)

UI:setPages({
	listing = listingPage,
	start = startPage,
	blank = blankPage
})

UI:setPage('start')
UI:start()
