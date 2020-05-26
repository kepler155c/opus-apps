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

local chunk = load([[
    local j = 5
    for i = 1, 5 do
        j = j * i
    end
    --table.insert(j, 5)
    return j]], nil, nil, _ENV)

local j = chunk()
print(j)

require('opus.util').print(coroutine)
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
