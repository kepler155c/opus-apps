local function m2(a)
    return a
end

local function method(times)
    local a = 2
    -- use step out to return out of method
    for _ = 1, times do
        a = a * a
    end
    return m2(a)
end

print('before')
term.current().clear()
print('after')

local i = 2
print(i)
local res = method(i)

dofile("rom/modules/main/cc/expect.lua")

print(res)
print('result: ' .. res)

error('f')
