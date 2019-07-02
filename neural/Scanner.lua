local Event      = require('opus.event')
local itemDB     = require('core.itemDB')
local UI         = require('opus.ui')
local Util       = require('opus.util')

local device     = _G.device
local gps        = _G.gps
local multishell = _ENV.multishell

local glasses = device['plethora:glasses']
local scanner = device['plethora:scanner'] or
	error('Plethora scanner must be equipped')

local projecting = { }

local function getPoint()
	local pt = { gps.locate() }
	if pt[1] then
		return {
			x = pt[1],
			y = pt[2],
			z = pt[3],
		}
	end
end

local offset = getPoint()
local canvas = glasses and glasses.canvas3d().create()

UI:configure('Scanner', ...)

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Scan',   event = 'scan' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		columns = {
			{ heading = 'Name',  key = 'displayName' },
			{ heading = 'Count', key = 'count', width = 5, align = 'right' },
		},
		sortColumn = 'displayName',
	},
	accelerators = {
		[ 'control-q' ] = 'quit',
	},
	detail = UI.SlideOut {
		menuBar = UI.MenuBar {
			buttons = {
				{ text = 'Back', event = 'cancel'  },
			},
		},
		grid = UI.ScrollingGrid {
			y = 2,
			columns = {
				{ heading = 'Name', key = 'name' },
				{ heading = 'Dmg',  key = 'metadata', width = 3 },
				{ heading = '  X',  key = 'x', width = 3, align = 'right' },
				{ heading = '  Y',  key = 'y', width = 3, align = 'right' },
				{ heading = '  Z',  key = 'z', width = 3, align = 'right' },
			},
			sortColumn = 'name',
			accelerators = {
				grid_select = 'inspect',
			},
		},
	},
}

function page:scan()
	local throttle = Util.throttle()
	self.blocks = scanner:scan()

	self.grid:setValues(Util.reduce(self.blocks,
		function(acc, b)
			local entry = itemDB:get(table.concat({ b.name, b.metadata }, ':'))
			if not entry then
				local meta = scanner.getBlockMeta(b.x, b.y, b.z)
				if meta.name == b.name and meta.metadata == b.metadata then
					entry = itemDB:add({
						name = meta.name,
						displayName = meta.displayName,
						damage = meta.metadata,
					})
				end
			end
			if entry then
				b.key = entry.displayName
				if acc[b.key] then
					acc[b.key].count = acc[b.key].count + 1
				else
					entry = Util.shallowCopy(entry)
					entry.lname = entry.displayName:lower()
					entry.count = 1
					entry.key = b.key
					acc[b.key] = entry
				end
			end
			throttle()
			return acc
		end,
		{ }))

	itemDB:flush()

	self.grid:draw()
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.count = Util.toBytes(row.count)
	return row
end

function page.detail:show(blocks, entry)
	self.grid:setValues(Util.filter(blocks, function(b) return b.key == entry.key end))
	self.target = entry
	if canvas then
		self.handler = Event.onInterval(.5, function()
			if not self.target then
				Event.off(self.handler)
				projecting = { }
				canvas.clear()
			else
				local t = self.target
				local scanned = scanner.scan()
				local pos = getPoint()

				if pos and offset then
					blocks = Util.reduce(scanned, function(acc, b)
						if b.name == t.name and b.metadata == t.damage then
							-- track block's world position
							b.id = table.concat({
								math.floor(pos.x + b.x),
								math.floor(pos.y + b.y),
								math.floor(pos.z + b.z) }, ':')
							acc[b.id] = b
						end
						return acc
					end, { })

					for _, b in pairs(blocks) do
						if not projecting[b.id] then
							projecting[b.id] = b
							pcall(function()
								b.box = canvas.addItem({
									pos.x - offset.x + b.x + -(pos.x % 1) + .5,
									pos.y - offset.y + b.y + -(pos.y % 1) + .5,
									pos.z - offset.z + b.z + -(pos.z % 1) + .5 },
									b.name, b.damage, .5)
							end)
							if not b.box then
								b.box = canvas.addBox(
									pos.x - offset.x + b.x + -(pos.x % 1) + .25,
									pos.y - offset.y + b.y + -(pos.y % 1) + .25,
									pos.z - offset.z + b.z + -(pos.z % 1) + .25,
									.5, .5, .5)
							end
							b.box.setDepthTested(false)
						end
					end

					for _, b in pairs(projecting) do
						if not blocks[b.id] then
							b.box.remove()
							projecting[b.id] = nil
						end
					end
				end
			end
		end)
	end
	return UI.SlideOut.show(self)
end

function page.detail:hide()
	self.target = nil
	return UI.SlideOut.hide(self)
end

function page:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'scan' then
		self:scan()

	elseif event.type == 'grid_select' and event.element == self.detail.grid then
		multishell.openTab({
			path = 'sys/apps/Lua.lua',
			args = { event.selected },
			focused = true,
		})

	elseif event.type == 'grid_select' and event.element == self.grid then
		self.detail:show(self.blocks, self.grid:getSelected())

	elseif event.type == 'cancel' then
		self.detail:hide()
	end

	UI.Page.eventHandler(self, event)
end

UI:setPage(page)

Event.onTimeout(0, function()
	page:scan()
	page:sync()
end)

UI:pullEvents()

if canvas then
	canvas:clear()
end
