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

local function update()
  local canvas  = device['plethora:glasses'] and device['plethora:glasses'].canvas()
  if canvas then
    local Tween  = require('ui.tween')

    canvas.clear()
    local w, h = canvas.getSize()
    local pos = { x = w / 2, y = h / 2 - 30 }
    local group = canvas.addGroup(pos)
    local function drawLine(k, line)
      for i = 1, #line do
        local pix = hex[line:sub(i, i)]
        if pix then
          group.addRectangle(i*1.5, k*2.25, 1.5, 2.25, pix)
        end
      end
    end

    for k,line in ipairs(opus) do
      drawLine(k, line)
    end
    os.sleep(.5)
    local tween = Tween.new(40, pos, { x = w - 60, y = h - 30 }, 'outBounce')
    repeat
      local finished = tween:update(1)
      os.sleep(0)
      group.setPosition(pos.x, pos.y)
    until finished
  end
end

kernel.run({
  title = 'opus',
  env = _ENV,
  hidden = true,
  fn = update,
})
