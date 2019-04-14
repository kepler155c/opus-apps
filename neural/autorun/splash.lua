local opus = {
  'fffff00',
  'ffff07000',
  'ff00770b00 4444',
  'ff077777444444444',
  'f07777744444444444',
  'f0000777444444444',
  '070000111744444',
  '777770000',
  '7777000000',
  '70700000000',
  '077000000000',
}

local hex = {
  ['0'] = 0xF0F0F04F,
  ['1'] = 0xF2B2334F,
  ['2'] = 0xE57FD84F,
  ['3'] = 0x99B2F24F,
  ['4'] = 0xDEDE6C4F,
  ['5'] = 0x7FCC194F,
  ['6'] = 0xF2B2CC4F,
  ['7'] = 0x4C4C4C4F,
  ['8'] = 0x9999994F,
  ['9'] = 0x4C99B24F,
  ['a'] = 0xB266E54F,
  ['b'] = 0x3366CC4F,
  ['c'] = 0x7F664C4F,
  ['d'] = 0x57A64E4F,
  ['e'] = 0xCC4C4C4F,
--  ['f'] = 0x191919FF, -- transparent
}
local canvas  = device['plethora:glasses'] and device['plethora:glasses'].canvas()
if canvas then
  canvas.clear() -- assuming we are the first to use the canvas
  local w, h = canvas.getSize()
  canvas.group = canvas.addGroup({ w - 30, h - 30 })
  local function drawLine(k, line)
    for i = 1, #line do
      local pix = hex[line:sub(i, i)]
      if pix then
        canvas.group.addRectangle(i*1.5, k*2.25, 1.5, 2.25, pix)
      end
    end
  end
  for k,line in ipairs(opus) do
    drawLine(k, line)
  end
end
