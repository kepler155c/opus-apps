local Event  = require('event')

local device = _G.device
local os     = _G.os

local args   = { ... }
local context = args[1]

local SHIELD_SLOT  = 2

Event.addRoutine(function()
  local lastTransfer
  while true do
    local sleepTime = 1.5
    if lastTransfer and os.clock() - lastTransfer < 3 then
      sleepTime = .25
    end

    os.sleep(context.socket and sleepTime or 5)
    if context.state.deposit then
      local neural = device.neuralInterface
      local inv = context.state.useShield and 'getEquipment' or 'getInventory'
      if not neural or not neural[inv] then
        _G._debug('missing Introspection module')
      elseif context.state.server and (context.state.useShield or context.state.slot) then
        local s, m = pcall(function()
          local method = neural[inv]
          local item = method and method().list()[context.state.useShield and SHIELD_SLOT or context.state.slot]
          if item then
            if context:sendRequest({
              request = 'deposit',
              slot = context.state.useShield and 'shield' or context.state.slot,
              count = item.count,
            }) then
              lastTransfer = os.clock()
            end
          end
        end)
        if not s and m then
          _G._debug(m)
        end
      end
    end
  end
end)
