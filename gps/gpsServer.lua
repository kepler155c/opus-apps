local Config = require('config')
local GPS    = require('gps')
local Util   = require('util')

local args       = { ... }
local gps 			 = _G.gps
local os         = _G.os
local peripheral = _G.peripheral
local term       = _G.term
local turtle     = _G.turtle
local vector     = _G.vector

local WIRED_MODEM = 'computercraft:wired_modem_full'
local CABLE       = 'computercraft:cable'
local ENDER_MODEM = 'computercraft:advanced_modem'

local positions = { }

local function build()
	if not turtle.has(WIRED_MODEM, 8) or
		 not turtle.has(CABLE, 4) or
		 not turtle.has(ENDER_MODEM, 4) then
		error([[Place into inventory:
 * 8 Wired modem (blocks)
 * 4 Network cables
 * 4 Ender modems]])
	end

	local blocks = {
		{ x =  1, y = 0, z =  0, b = WIRED_MODEM },
		{ x =  2, y = 0, z =  0, b = CABLE },
		{ x =  2, y = 1, z =  0, b = CABLE },
		{ x =  2, y = 2, z =  0, b = WIRED_MODEM },
		{ x =  2, y = 3, z =  0, b = ENDER_MODEM },

		{ x = -1, y = 0, z =  0, b = WIRED_MODEM },
		{ x = -2, y = 0, z =  0, b = CABLE },
		{ x = -2, y = 1, z =  0, b = CABLE },
		{ x = -2, y = 2, z =  0, b = WIRED_MODEM },
		{ x = -2, y = 3, z =  0, b = ENDER_MODEM },

		{ x =  0, y = 0, z =  1, b = WIRED_MODEM },
		{ x =  0, y = 0, z =  2, b = WIRED_MODEM },
		{ x =  0, y = 1, z =  2, b = ENDER_MODEM },

		{ x =  0, y = 0, z = -1, b = WIRED_MODEM },
		{ x =  0, y = 0, z = -2, b = WIRED_MODEM },
		{ x =  0, y = 1, z = -2, b = ENDER_MODEM },
	}

	for _,v in ipairs(blocks) do
		turtle.placeDownAt(v, v.b)
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

local function server()
	local modems = Config.load('gpsServer')
	local computers = { }

	if #modems == 0 then
		error('Missing usr/config/gpsServer configuration file')
	end

	for k, modem in pairs(modems) do
		Util.merge(modem, peripheral.wrap(k))
		modem.open(gps.CHANNEL_GPS)
	end

	while true do
		local e, p1, p2, p3, p4, p5 = os.pullEvent( "modem_message" )
		if e == "modem_message" then
			-- We received a message from a modem
			local side, channel, computerId, sMessage, distance = p1, p2, p3, p4, p5
			if channel == gps.CHANNEL_GPS and sMessage == "PING" then
				-- We received a ping message on the GPS channel, send a response
				local modem = modems[side]
				if modem then
					local computer = memoize(computers, computerId, function() return { } end)
					table.insert(computer, {
						position = vector.new(modem.x, modem.y, modem.z), distance = distance
					})
					if #computer == 4 then
						local pt = GPS.trilaterate(computer)
						if pt then
							positions[computerId] = pt
							term.clear()
							for k,v in pairs(positions) do
								Util.print('ID: %d: %s %s %s', k, v.x, v.y, v.z)
							end
						end
						computers[computerId] = nil
					end
					for _, modem in pairs(modems) do
						modem.transmit( computerId, gps.CHANNEL_GPS, { modem.x, modem.y, modem.z })
					end
				end
			end
		end
	end
end

if args[1] == 'build' then
	local y = tonumber(args[2] or 0)

	turtle.setPoint({ x = 0, y = -y, z = 0, heading = 0 })
	build()
	turtle._goto({ x = 0, y = 0, z = 0, heading = 0 })

	print('Activate all modems')
	print('Press enter when ready')
	_G.read()

	local modems = { }
	peripheral.find('modem', function(name, modem)
		if modem.isWireless() then
			modems[name] = { x = 0, y = 0, z = 0 }
		end
	end)

	Config.update('gpsServer', modems)

	print([[
Configuration file usr/config/gpsServer created.
Add coordinates for each modem.
Use the position of the wired modem below the wireless modem]])

elseif args[1] == 'server' then
	server()

else

	error('Syntax: gps [build|server]')
end
