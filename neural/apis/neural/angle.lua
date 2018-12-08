local Angle = { }

function Angle.towards(x, y, z)
  return math.deg(math.atan2(-x, z)), 0
end

function Angle.away(x, y, z)
  return math.deg(math.atan2(x, -z)), 0
end

return Angle
