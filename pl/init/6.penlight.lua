--[[
local getfenv = _G.getfenv

-- penlight requires a global package to determine path separator
-- some funky things in penlight regarding global access
_G.package = {
    config = '/\n:\n?\n!\n-',
}

_G.require = function(module)
    for i = 2, 3 do
        local env = getfenv(i)
        if env ~= _G then
            return env.require(module)
        end
    end
    error('invalid environment for require')
end
]]