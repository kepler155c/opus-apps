local w, h = term.getSize()

term.clear()
term.setCursorPos(1, 1)

local t = { }
for i = 1, 8 do
  table.insert(t, '---')
end

for i = 1, 255 do
  table.insert(t, string.format('%d %c', i, i))
end

textutils.pagedTabulate(t)
