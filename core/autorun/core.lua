if fs.exists('packages/core/lavaRefuel.lua') then fs.delete('packages/core/lavaRefuel.lua') end
if fs.exists('packages/core/t.lua') then fs.delete('packages/core/t.lua') end

_ENV.shell.setCompletionFunction("packages/core/edit.lua",
  function(shell, nIndex, sText)
    if nIndex == 1 then
      return _G.fs.complete(sText, shell.dir(), true, false)
    end
  end)
