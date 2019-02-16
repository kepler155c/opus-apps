local Util = require('util')

local turtle = _G.turtle

if turtle then
  function turtle.scan(blocks)
    local pt = turtle.point
    local scanner = device['plethora:scanner'] or error('Scanner not equipped')

    if not blocks then
      return Util.each(scanner:scan(), function(b)
        b.x = pt.x + b.x
        b.y = pt.y + b.y
        b.z = pt.z + b.z
      end)
    end

    return Util.filter(scanner:scan(), function(b)
      if blocks[b.name] then
        b.x = pt.x + b.x
        b.y = pt.y + b.y
        b.z = pt.z + b.z
        return true
      end
    end)
  end
end
