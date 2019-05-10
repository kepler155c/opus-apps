local colors = _G.colors
local term   = _G.term

local w, h = term.getSize()

local cmap = {
  [ 0xCC2200 ] = colors.red,
  [ 0x44CC00 ] = colors.lime,
  [ 0xB0B00F ] = colors.yellow,
  [ 0xFFFFFF ] = colors.white,
}

return {
  gpu = function()
    return {
      setForeground = function(c) term.setTextColor(cmap[c]) end,
    }
  end,
  getViewport = term.getSize,
  window = {
    width = w, height = h,
  }
}