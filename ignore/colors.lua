_G.requireInjector(_ENV)
local Util = require('util')

local colors = _G.colors
local term   = _G.term

local w = term.getSize()
local x, y = 1, 2
local filler = string.rep(' ', w)
term.clear()

local colorTable = Util.filter(colors, function(c)
  return type(c) == 'number'
end)

term.setTextColor(colors.black)
for k,v in Util.spairs(colorTable, function(a, b) return a < b end) do
  term.setBackgroundColor(v)
  for i = 0, 1 do
    term.setCursorPos(x, y + i)
    term.write(filler:sub(1, 9))
  end
  term.setCursorPos(x + ((9 - #k) / 2), y)
  term.write(k)
  local cs = tostring(v)
  term.setCursorPos(x + ((9 - #cs) / 2), y + 1)
  term.write(cs)
  x = x + 9
  if x + 9 > w + 1 then
    y = y + 2
    x = 1
  end
end
if x > 1 then
  y = y + 2
end
term.setCursorPos(1, y)
