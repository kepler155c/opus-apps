local Event   = require('event')
local Point   = require('point')
local Proxy   = require('proxy')
local Util    = require('util')

local device  = _G.device
local network = _G.network

local glasses = device['plethora:glasses'] or error('Overlay glasses are required')

local id = tonumber(({...})[1]) or
  error('Syntax: Vision <id>')

local blacklist = {
  [ 'minecraft:air'] = true,
}
local turtle, socket = Proxy.create(id, 'device/plethora:scanner')
if not turtle then
  error('nope')
end
local current
local projecting = { }
local canvas = glasses.canvas3d().create()

local function displayBlocks(scanned)
print('redrawing')
  local blocks = { }
  for _, b in pairs(scanned) do
    -- track block's world position
    b.id = table.concat({ b.x, b.y, b.z }, ':')
    blocks[b.id] = b
  end

  for _, b in pairs(blocks) do
    if not projecting[b.id] then
      projecting[b.id] = b
      pcall(function()
        b.box = canvas.addItem({ b.x / 40, b.y / 40 - .25, b.z / 40 }, b.name, b.damage, .025)
      end)
    --      b.box.setDepthTested(false)
    end
  end

  for _, b in pairs(projecting) do
    if b.box and not blocks[b.id] then
      b.box.remove()
      projecting[b.id] = nil
    end
  end
end

Event.onInterval(1, function()
  local t = network[id]

  --if t and t.point and (not current or not Point.same(t.point, current)) then
  --  current = t.point
    local scanned = turtle.scan(blacklist)
    if scanned then
      displayBlocks(Util.filter(turtle.scan(), function(b)
        if not blacklist[b.name] then
          return true
        end
      end))
    end
  --end
end)

Event.pullEvents()
canvas:clear()
socket:close()
