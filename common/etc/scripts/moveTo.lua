local turtle = _G.turtle

turtle.run(function()
    local GPS = require('opus.gps')

    if not turtle.enableGPS() then
        error('turtle: No GPS found')
    end

    local pt = {GPS}

    if not turtle.pathfind(pt) then
        error('Unable to go to location')
    end
end)
