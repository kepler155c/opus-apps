_ENV.shell.setCompletionFunction("packages/common/edit.lua",
  function(shell, nIndex, sText)
    if nIndex == 1 then
      return _G.fs.complete(sText, shell.dir(), true, false)
    end
  end)
