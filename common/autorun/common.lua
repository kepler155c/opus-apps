local c = function(shell, nIndex, sText)
	if nIndex == 1 then
		return _G.fs.complete(sText, shell.dir(), true, false)
	end
end

_ENV.shell.setCompletionFunction("packages/common/edit.lua", c)
_ENV.shell.setCompletionFunction("packages/common/hexedit.lua", c)

fs.mount('packages/common/hexedit.lua', 'urlfs', 'https://pastebin.com/raw/Ds9ajsp4')
