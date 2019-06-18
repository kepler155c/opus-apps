local colors = _G.colors
local term   = _G.term

local w, h = term.getSize()

local cmap = {
	[ 0xCC2200 ] = colors.red,
	[ 0x44CC00 ] = colors.lime,
	[ 0xB0B00F ] = colors.yellow,
	[ 0xFFFFFF ] = colors.white,

	[ 0xb000b0 ] = colors.purple,
	[ 0x00FF00 ] = colors.green,
	[ 0xFF0000 ] = colors.red,
	[ 0x00FFFF ] = colors.cyan,
	[ 0x000000 ] = colors.black,
}

return {
	gpu = function()
		local current = 0xFFFFFF
		return {
			setForeground = function(c)
				current = c
				term.setTextColor(cmap[c])
			end,
			getForeground = function() return current end,
		}
	end,
	getViewport = term.getSize,
	window = {
		width = w, height = h,
	}
}