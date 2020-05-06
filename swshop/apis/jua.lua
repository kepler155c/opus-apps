local juaVersion = "0.0"

juaRunning = false
eventRegistry = {}
timedRegistry = {}

local function registerEvent(event, callback)
	if eventRegistry[event] == nil then
		eventRegistry[event] = {}
	end

	table.insert(eventRegistry[event], callback)
end

local function registerTimed(time, repeating, callback)
	if repeating then
		callback(true)
	end

	table.insert(timedRegistry, {
		time = time,
		repeating = repeating,
		callback = callback,
		timer = os.startTimer(time)
	})
end

local function discoverEvents(event)
		local evs = {}
		for k,v in pairs(eventRegistry) do
				if k == event or string.match(k, event) or event == "*" then
						for i,v2 in ipairs(v) do
								table.insert(evs, v2)
						end
				end
		end

		return evs
end

function on(event, callback)
	registerEvent(event, callback)
end

function setInterval(callback, time)
	registerTimed(time, true, callback)
end

function setTimeout(callback, time)
	registerTimed(time, false, callback)
end

function tick()
	local eargs = {os.pullEventRaw()}
	local event = eargs[1]

	if eventRegistry[event] == nil then
		eventRegistry[event] = {}
	else
		local evs = discoverEvents(event)
		for i, v in ipairs(evs) do
			v(unpack(eargs))
		end
	end

	if event == "timer" then
		local timer = eargs[2]

		for i = #timedRegistry, 1, -1 do
			local v = timedRegistry[i]
			if v.timer == timer then
				v.callback(not v.repeating or nil)

				if v.repeating then
					v.timer = os.startTimer(v.time)
				else
					table.remove(timedRegistry, i)
				end
			end
		end
	end
end

function run()
	os.queueEvent("init")
	juaRunning = true
	while juaRunning do
		tick()
	end
end

function go(func)
	on("init", func)
	run()
end

function stop()
	juaRunning = false
end

function await(func, ...)
	local args = {...}
	local out
	local finished
	func(function(...)
		out = {...}
		finished = true
	end, unpack(args))
	while not finished do tick() end
	return unpack(out)
end

return {
	on = on,
	setInterval = setInterval,
	setTimeout = setTimeout,
	tick = tick,
	run = run,
	go = go,
	stop = stop,
	await = await
}
