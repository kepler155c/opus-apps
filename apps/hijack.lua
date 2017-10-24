_G.requireInjector()

local Socket = require('socket')

if not ... then
	local turtle = _G.turtle

  while true do
    print('hijack: waiting for connections')
    local socket = Socket.server(188)

    print('hijack: connection from ' .. socket.dhost)

    local methods = { }
		for k,v in pairs(turtle) do
			if type(v) == 'function' then
				table.insert(methods, k)
			end
		end
		socket:write(methods)

	  while true do
	    local data = socket:read()
	    if not data then
	      break
	    end
	    socket:write({ turtle[data.fn](unpack(data.args)) })
	  end
  end

else
	local remoteId = ({ ... })[1]
	local socket, msg = Socket.connect(remoteId, 188)

	if not socket then
	  error(msg)
	end

	local methods = socket:read()

	local turtle = { }
	for _,method in pairs(methods) do
		turtle[method] = function(...)
			socket:write({ fn = method, args = { ... } })
			local resp = socket:read()
			return table.unpack(resp)
		end
	end

	_G.turtle = turtle
	os.pullEventRaw('terminate')
	socket:close()
end
