local Config = require('opus.config')
local GPS    = require('opus.gps')
local Util   = require('opus.util')
local UI     = require('opus.ui')
local Event  = require('opus.event')

local colors     = _G.colors
local fs         = _G.fs
local gps        = _G.gps
local os         = _G.os
local peripheral = _G.peripheral
local read       = _G.read
local term       = _G.term
local turtle     = _G.turtle
local vector     = _G.vector

local WIRED_MODEM = 'computercraft:wired_modem_full'
local CABLE       = 'computercraft:cable'
local ENDER_MODEM = 'computercraft:advanced_modem'

local STARTUP_FILE = 'usr/autorun/gpsServer.lua'

local positions = { }

UI:configure('gps', ...)
local args = Util.parse( ... )

local page = UI.Page {
	menuBar = UI.MenuBar {
		showBackButton = true,
		buttons = {
			{ text = 'Clear:', inactive = true },
			{ text = 'Inactive', event = 'clear_inactive' },
			{ text = 'All', event = 'clear_all' },
		},
	},
	grid = UI.ScrollingGrid {
		y = 2,
		sortColumn = 'id',
		autospace = true,
		focusIndicator = ' ',
		columns = {
			{ key = 'hbeat', width = 1, textColor = colors.red },
			{ heading = 'ID', key = 'id', align = 'right', width = 5, textColor = colors.pink },
			{ heading = 'X', key = 'x', align = 'right', width = 6 },
			{ heading = 'Y', key = 'y', align = 'right', width = 4 },
			{ heading = 'Z', key = 'z', width = 6, align = 'right' },
			{ heading = 'Dist', key = 'dist', align = 'right', width = 7, textColor = colors.orange },
		}
	}
}
page:setFocus(page.grid)

function page.grid:getDisplayValues(row)
	row = Util.shallowCopy(row)
	row.dist = Util.toBytes(Util.round(row.dist, 2))
	row.hbeat = row.hbeat and "\3" or "\183"
	return row
end

function page.grid:getRowTextColor(row, selected)
	return row.changed and colors.yellow or
				 not row.alive and colors.lightGray or
				 UI.Grid.getRowTextColor(self, row, selected)
end

function page.menuBar:eventHandler(event)
	if event.type == 'clear_inactive' then
		for id, detail in pairs(positions) do
			if not detail.alive then
				positions[id] = nil
			end
		end
	elseif event.type == 'clear_all' then
		for id in pairs(positions) do
			positions[id] = nil
		end
	else return UI.MenuBar.eventHandler(self, event)
	end
	page.grid:update()
	page:draw()
	page:sync()
	return true
end

local function build()
	if not turtle.has(WIRED_MODEM, 5) or
		 not turtle.has(CABLE, 8) or
		 not turtle.has(ENDER_MODEM, 4) then
		error([[Place into inventory:
 * 5 Wired modem (blocks)
 * 8 Network cables
 * 4 Ender modems]])
	end

	term.clear()
	term.setCursorPos(1, 2)
	term.setTextColor(colors.yellow)
	print('    Turtle must be facing east\n')
	term.setTextColor(colors.white)
	print(' Enter to continue or ctrl-t to abort')
	read()

	term.clear()
	term.setCursorPos(1, 2)
	print('building...')

	local blocks = {
		{ x =  0, y = 0, z =  0, b = WIRED_MODEM },

		{ x =  1, y = 0, z =  0, b = CABLE },
		{ x =  2, y = 0, z =  0, b = CABLE },
		{ x =  2, y = 1, z =  0, b = CABLE },
		{ x =  2, y = 2, z =  0, b = WIRED_MODEM },
		{ x =  2, y = 3, z =  0, b = ENDER_MODEM },

		{ x = -1, y = 0, z =  0, b = CABLE },
		{ x = -2, y = 0, z =  0, b = CABLE },
		{ x = -2, y = 1, z =  0, b = CABLE },
		{ x = -2, y = 2, z =  0, b = WIRED_MODEM },
		{ x = -2, y = 3, z =  0, b = ENDER_MODEM },

		{ x =  0, y = 0, z =  1, b = CABLE },
		{ x =  0, y = 0, z =  2, b = WIRED_MODEM },
		{ x =  0, y = 1, z =  2, b = ENDER_MODEM },

		{ x =  0, y = 0, z = -1, b = CABLE },
		{ x =  0, y = 0, z = -2, b = WIRED_MODEM },
		{ x =  0, y = 1, z = -2, b = ENDER_MODEM },
	}

	for _,v in ipairs(blocks) do
		turtle.placeDownAt(v, v.b)
	end
end

local function configure()
	local function getOption(prompt)
		while true do
			term.write(prompt)
			local value = read()
			if tonumber(value) then
				return tonumber(value)
			end
			print('Invalid value, try again.\n')
		end
	end

	print('Server configuration\n\n')

	Config.update('gpsServer', {
		x = getOption('Turtle x: '),
		y = getOption('Turtle y: '),
		z = getOption('Turtle z: '),
		east = getOption('East modem: modem_'),
		south = getOption('South modem: modem_'),
		west = getOption('West modem: modem_'),
		north = getOption('North modem: modem_'),
	})

	print('Make sure all wired modems are activated')
	print('Enter to continue')
	read()

	if not fs.exists(STARTUP_FILE) then
		Util.writeFile(STARTUP_FILE,
			[[shell.openForegroundTab('gpsServer.lua server')]])
		print('Autorun program created: ' .. STARTUP_FILE)
	end
end

local function memoize(t, k, fn)
	local e = t[k]
	if not e then
		e = fn()
		t[k] = e
	end
	return e
end

local function server(mode)
	local computers = { }

	if not fs.exists('usr/config/gpsServer') then
		configure()
	end

	local config = Config.load('gpsServer')

	local modems = { }
	modems['modem_' .. config.east]  = { x = config.x + 2, y = config.y + 1, z = config.z     }
	modems['modem_' .. config.west]  = { x = config.x - 2, y = config.y + 1, z = config.z     }
	modems['modem_' .. config.south] = { x = config.x,     y = config.y - 1, z = config.z + 2 }
	modems['modem_' .. config.north] = { x = config.x,     y = config.y - 1, z = config.z - 2 }

	for k, modem in pairs(modems) do
		Util.merge(modem, peripheral.wrap(k) or { })
		Util.print('%s: %d %d %d', k, modem.x, modem.y, modem.z)
		if not modem.open then
			error('Modem is not activated or connected: ' .. k)
		end
		if mode == 'gps' then
			modem.open(gps.CHANNEL_GPS)
		elseif mode == 'snmp' then
			modem.open(999)
		end
	end

	print('\nStarting GPS Server')

	local function getPosition(computerId, modem, distance, msg)
		local computer = memoize(computers, computerId, function() return { } end)
		table.insert(computer, {
			position = vector.new(modem.x, modem.y, modem.z),
			distance = distance,
		})
		if #computer == 4 then
			local pt = GPS.trilaterate(computer)
			if pt then
				local comp = { lastPos = {} }
				if positions[computerId] then
					comp = positions[computerId]
				end

				comp.lastPos.x = comp.x or 0
				comp.lastPos.y = comp.y or 0
				comp.lastPos.z = comp.z or 0
				comp.x = pt.x
				comp.y = pt.y
				comp.z = pt.z
				comp.id = computerId
				comp.hbeat = not comp.hbeat
				comp.alive = true
				comp.timestamp = os.clock()
				comp.dist = (vector.new(config.x, config.y, config.z) - vector.new(comp.x, comp.y, comp.z)):length()
				if (comp.x ~= comp.lastPos.x or comp.y ~= comp.lastPos.y or comp.z ~= comp.lastPos.z) then
					comp.changed = true
					comp.lastChanged = os.clock()
				end
				if mode == 'snmp' and type(msg) == "table" then
					comp.label = msg.label or '*'
				end

				positions[computerId] = comp
			end

			computers[computerId] = nil
			page.grid.values = positions
			page.grid:update()
			page.grid:draw()
			page.grid:sync()
		end
	end

	Event.on('modem_message', function(_, side, channel, computerId, message, distance)
		if distance and modems[side] then
			if mode == 'gps' and channel == gps.CHANNEL_GPS and message == "PING" then
				for _, modem in pairs(modems) do
					modem.transmit(computerId, gps.CHANNEL_GPS, { modem.x, modem.y, modem.z })
				end
				getPosition(computerId, modems[side], distance)
			end

			if mode == 'snmp' and channel == 999 then
				getPosition(computerId, modems[side], distance, message)
			end
		end
	end)

	Event.onInterval(1, function()
		local resync = false
		for _, detail in pairs(positions) do
			if os.clock() - detail.lastChanged > 10 then
				detail.changed = false
				resync = true
			end
			if os.clock() - detail.timestamp > 60 and detail.alive then
				detail.alive = false
				detail.hbeat = false
				resync = true
			end
		end
		if resync then
			page:draw()
			page:sync()
		end
	end)
end

if args[1] == 'build' then
	local y = tonumber(args[2] or 0)

	turtle.setPoint({ x = 0, y = -y, z = 0, heading = 0 })
	build()
	turtle.go({ x = 0, y = 1, z = 0, heading = 0 })

	configure()

	server('gps')

elseif args[1] == 'server' then
	server('gps')

elseif args[1] == 'snmp' then
	table.insert(page.grid.columns,
		{ heading = 'Label', key = 'label', textColor = colors.cyan }
	)
	page.grid:adjustWidth()
	server('snmp')

else
	error('Syntax: gpsServer [build | server | snmp]')

end

UI:setPage(page)
UI:pullEvents()
