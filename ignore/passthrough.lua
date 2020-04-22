local _rep   = string.rep
local _sub   = string.sub
local colors = _G.colors

local palette = { }

for n = 1, 16 do
	palette[2 ^ (n - 1)]     = _sub("0123456789abcdef", n, n)
end

local swindow = { }

function swindow.createPassthrough(parent, wx, wy, width, height)
	local window = { }
	local cx, cy = 1, 1
	local blink = false
	local fg = colors.white
	local bg = colors.black

	local function crop(text, x)
		local w = #text

		if x < 1 then
			text = _sub(text, 2 - x)
			w = w + x - 1
			x = 1
		end

		if x + w - 1 > width then
			text = _sub(text, 1, width - x + 1)
		end

		return text
	end

	local function blit(text, fg, bg)
		parent.setCursorPos(cx + wx - 1, cy + wy - 1)
		parent.blit(text, fg, bg)
		cx = cx + #text
	end

	function window.write(text)
		if cy > 0 and cy <= height then
			text = crop(tostring(text), cx)
			if #text > 0 then
				--parent.setCursorPos(cx + wx - 1, cy + wy - 1)
				blit(text, _rep(palette[fg], #text), _rep(palette[bg], #text))
			end
		end
	end

    function window.blit(text, fg, bg)
		if cy > 0 and cy <= height then
			text = crop(tostring(text), cx)
			if #text > 0 then
				blit(text, crop(tostring(fg), cx), crop(tostring(bg), cx))
			end
		end
    end

	function window.clear()
		local filler = _rep(' ', width)
		for i = 1, height do
			parent.setCursorPos(wx, i + wy - 1)
			parent.write(filler)
        end
    end

    function window.clearLine()
		if cy > 0 and cy <= height then
			local filler = _rep(' ', width)
			parent.setCursorPos(cx + wx - 1, cy + wy - 1)
			parent.write(filler)
        end
    end

    function window.getCursorPos()
        return cx, cy
    end

    function window.setCursorPos(x, y)
        cx = math.floor(x)
		cy = math.floor(y)
		parent.setCursorPos(cx + wx - 1, cy + wy - 1)
    end

	function window.setCursorBlink(b)
		blink = b
		parent.setCursorBlink(b)
	end

	function window.getCursorBlink()
		return blink
	end

	window.isColor = parent.isColor
	window.isColour = parent.isColour
	window.setPaletteColour = parent.setPaletteColour
	window.setPaletteColor = parent.setPaletteColor
	window.getPaletteColour = parent.getPaletteColour
    window.getPaletteColor = parent.getPaletteColour
    window.setBackgroundColor = parent.setBackgroundColor
    window.setBackgroundColour = parent.setBackgroundColor
    window.getBackgroundColor = parent.getBackgroundColor
    window.getBackgroundColour = parent.getBackgroundColor
	window.setVisible = parent.setVisible
	window.redraw = function() end --parent.redraw

	function window.getTextColor()
		return fg
	end
	window.getTextColour = window.getTextColor

	function window.setTextColor(textColor)
		fg = textColor
		parent.setTextColor(fg)
	end
    window.setTextColour = window.setTextColor

	function window.restoreCursor()
		parent.setCursorPos(cx + wx - 1, cy + wy - 1)
		parent.setTextColor(fg)
		parent.setCursorBlink(blink)
	end

    function window.getSize()
        return width, height
    end

    function window.scroll( n )
		if n ~= 0 then
			local lines = { }
			for i = 1, height do
				lines[i] = { parent.getLine(wy + i - 1) }
			end

			for newY = 1, height do
                local y = newY + n
				parent.setCursorPos(wx, wy + newY - 1)
				if y >= 1 and y <= height then
					parent.blit(table.unpack(lines[y]))
				else
					parent.blit(
						_rep(' ', width),
						_rep(palette[fg], width),
						_rep(palette[bg], width))
                end
			end
			parent.setCursorPos(cx + wx - 1, cy + wy - 1)
        end
    end

	function window.getLine(y)
		local t, tc, bc = parent.getLine(y + cy - 1)
		return t:sub(1, width), tc:sub(1, width), bc:sub(1, width)
    end

    function window.getPosition()
        return wx, wy
    end

    function window.reposition(nNewX, nNewY, nNewWidth, nNewHeight, newParent)
        wx = nNewX
		wy = nNewY
		width = nNewWidth
		height = nNewHeight

		window.restoreCursor()
    end

    return window
end

return swindow
