requireInjector(getfenv(1))

local Util = require('util')

local Configurator = { }

function Configurator.get()
  print('Select device')
  for k,v in pairs(device) do
    Util.print('%s [%s]', v.name, v.side)
  end
end

Configurator.get()

return Configurator
