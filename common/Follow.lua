local Event  = require('opus.event')
local GPS    = require('opus.gps')
local Point  = require('opus.point')
local Socket = require('opus.socket')
local Swarm  = require('core.swarm')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local colors  = _G.colors
local network = _G.network
local os      = _G.os

local swarm = Swarm()
local gpt   = GPS.getPoint() or error('GPS not found')
local pts, blocks

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Range', event = 'range' },
			{ text = 'Stop',  event = 'stop'  },
		},
		mode = UI.Chooser {
			x = -16,
			choices = {
				{ name = 'No breaking', value = 'digNone'    },
				{ name = 'Destructive', value = 'turtleSafe' },
			},
			value = 'digNone',
		},
	},
	grid = UI.ScrollingGrid {
		y = 2, ey = -2,
		columns = {
			{ heading = 'Label',  key = 'label'    },
			{ heading = 'Dist',   key = 'distance' },
			{ heading = 'Status', key = 'status'   },
			{ heading = 'Fuel',   key = 'fuel'     },
		},
		sortColumn = 'distance',
		autospace = true,
	},
	range = UI.SlideOut {
		y = -7, height = 7,
		titleBar = UI.TitleBar {
			event = 'cancel',
			title = 'Enter range',
		},
		notice = UI.TextArea {
			x = 2, ex = -2, y = 3, ey = 4,
			value =
[[Select all turtles within a specified range]],
		},
		entry = UI.TextEntry {
			y = 6, x = 2, ex = 10,
			limit = 4,
			shadowText = 'range',
			accelerators = {
				enter = 'select_range',
			},
		},
		button = UI.Button {
			x = 12, y = 6,
			text = 'Apply',
			event = 'select_range',
		}
	},
}

function page.grid:getRowTextColor(row, selected)
	if swarm.pool[row.id] then
		return colors.yellow
	end
	return UI.ScrollingGrid.getRowTextColor(self, row, selected)
end

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	if row.fuel then
		row.fuel = row.fuel > 0 and Util.toBytes(row.fuel) or ''
	end
	if row.distance then
		row.distance = Util.round(row.distance, 1)
	end
	return row
end

function page:enable()
	local function update()
		local t = { }
		for _,v in pairs(network) do
			if v.fuel and v.active and v.fuel > 0 and v.distance then
				table.insert(t, v)
			end
		end
		self.grid:setValues(t)
	end

	Event.onInterval(3, function()
		update()
		self.grid:draw()
		self:sync()
	end)

	update()

	UI.Page.enable(self)
end

local function follow(member)
	local turtle = member.turtle
	turtle.reset()
	turtle.set({
		digPolicy = page.menuBar.mode.value,
		status = 'Following',
	})

	if not turtle.enableGPS(nil, true) then
		error('turtle: No GPS found')
	end

	member.snmp = Socket.connect(member.id, 161)
	member.snmp.co = coroutine.running()

	local pt

	while true do
		while pt and Point.same(gpt, pt) do
			os.sleep(.5)
		end
		pt = Point.copy(gpt)

		local cpt = Point.closest(turtle.getPoint(), pts)

		turtle.abort(false)
		if turtle.pathfind(cpt, { blocks = blocks }) then
			turtle.headTowards(pt)
		end
	end
end

function swarm:onRemove(member, status, message)
	if member.socket then
		pcall(function()
			member.turtle.set({ status = 'idle' })
			member.turtle.abort(true)
		end)
	end
	if member.snmp then
		member.snmp:close()
		member.snmp = nil
	end
	if not status then
		_G._syslog(message)
	end
end

function page:eventHandler(event)
	if event.type == 'grid_select' then
		if not swarm.pool[event.selected.id] then
			swarm:add(event.selected.id)
			swarm:run(follow)
		else
			swarm:remove(event.selected.id)
		end
		self.grid:draw()

	elseif event.type == 'choice_change' then
		local script = string.format('turtle.set({ digPolicy = "%s"})', event.value)
		for _, member in pairs(swarm.pool) do
			member.snmp:write({ type = 'scriptEx', args = script })
		end

	elseif event.type == 'stop' then
		for id in pairs(swarm.pool) do
			swarm:remove(id)
		end

	elseif event.type == 'range' then
		self.range:show()

	elseif event.type == 'cancel' then
		self.range:hide()

	elseif event.type == 'select_range' then
		local range = tonumber(self.range.entry.value)

		if range and range > 0 then
			for id, v in pairs(network) do
				if not swarm.pool[id] then
					if v.fuel and v.active and v.fuel > 0 and v.distance and v.distance <= range then
						swarm:add(id)
					end
				end
			end
			swarm:run(follow)
			self.range:hide()
		end
	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

Event.addRoutine(function()
	while true do
		local pt = GPS.getPoint()
		if not pts or (pt and not Point.same(pt, gpt)) then
			gpt = pt
			pts = {
				{ x = pt.x + 2, z = pt.z,     y = pt.y },
				{ x = pt.x - 2, z = pt.z,     y = pt.y },
				{ x = pt.x,     z = pt.z + 2, y = pt.y },
				{ x = pt.x,     z = pt.z - 2, y = pt.y },
			}
			blocks = { }

			local function addBlocks(tpt)
				table.insert(blocks, tpt)
				local apts = Point.adjacentPoints(tpt)
				for _,apt in pairs(apts) do
					table.insert(blocks, apt)
				end
			end

			-- don't run into player
			addBlocks(pt)
			addBlocks(Point.above(pt))

			for _, member in pairs(swarm.pool) do
				if member.snmp then
					member.snmp:write({ type = 'scriptEx', args = 'turtle.abort(true)' })
				end
			end
		end
		os.sleep(1)
	end
end)

UI:setPage(page)
UI:pullEvents()

swarm:stop()
