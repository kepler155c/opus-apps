--[[
    -- a very simple debugger implementation
    local dbg = require('debugger')
    dbg.read = function(snapshot)
        print(('%s: %d'):format(snapshot.info.source, snapshot.info.currentline))
        write('> ')
        return read()
    end
    dbg.stopIn(debug.getinfo(1).func)
]]

local function m2(a)
    return a
end

local function method(times)
    local a = 2
    for _ = 1, times do
        a = a * a
    end
    return m2(a)
end

local Event = require('opus.event')

Event.on('event1', function()
    print('event1')
end)

Event.on('event2', function()
    print('event2')
end)

Event.onTimeout(10, function()
    Event.exitPullEvents()
end)

local function xx()
    os.queueEvent('event1')
    os.queueEvent('event2')

    Event.pullEvents()
end
xx()

local chunk = load([[
    local j = 5
    for i = 1, 5 do
        j = j * i
    end
    --table.insert(j, 5)
    return j]], nil, nil, _ENV)

local j = chunk()
print(j)

local co = coroutine.create(function(args)
    print('in coroutine')
    return 'hi'
end)

local _, t = coroutine.resume(co, 'test')
while coroutine.status(co) ~= 'dead' do
    coroutine.resume(co, os.pullEvent())
    --print('alive')
end
print(coroutine.status(co))

print(t)

local i = 2
print(i)
local res = method(i)

dofile("rom/modules/main/cc/expect.lua")

print(res)
print('result: ' .. res)

table.insert(res, 5)
