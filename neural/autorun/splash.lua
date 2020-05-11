local device = _G.device
local kernel = _G.kernel

local opus = {
	'fffff00',
	'ffff07000',
	'ff00770b00f4444',
	'ff077777444444444',
	'f07777744444444444',
	'f0000777444444444',
	'070000111744444',
	'777770000',
	'7777000000',
	'70700000000',
	'077000000000',
}

local function update()
	local canvas = device['plethora:glasses'] and device['plethora:glasses'].canvas()
	if canvas then
		local Tween = require('opus.ui.tween')
		local Glasses = require('neural.glasses')

		local pal = Glasses.getPalette(0x4f)
		pal['f'] = nil -- transparent

		canvas.clear()
		local w, h = canvas.getSize()
		local pos = { x = w / 2, y = h / 2 - 30 }
		local group = canvas.addGroup(pos)
		local function drawLine(k, line)
			for i = 1, #line do
				local pix = pal[line:sub(i, i)]
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

kernel.run(_ENV, {
	hidden = true,
	fn = update,
})
