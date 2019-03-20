-- Original concept by
--   HydroNitrogen (a.k.a. GoogleTech, Wendelstein7)
--   Bram S. (a.k.a ThatBram0101, bram0101)
-- see: https://energetic.pw/computercraft/ore3d/assets/ore3d.lua

-- Updated to use new(ish) canvas3d

local gps        = _G.gps
local keys       = _G.keys
local os         = _G.os
local parallel   = _G.parallel
local peripheral = _G.peripheral

local function showRequirements(missing)
  print([[A neural interface is required containing:
 * Overlay glasses
 * Scanner
]])
  error('Missing: ' .. missing)
end

local modules = peripheral.find('neuralInterface')
if not modules then
  showRequirements('Neural interface')
elseif not modules.canvas then
  showRequirements('Overlay glasses')
elseif not modules.scan then
  showRequirements('Scanner module')
end

local function getPoint()
  local pt = { gps.locate() }
  if pt[1] then
    return {
      x = pt[1],
      y = pt[2],
      z = pt[3],
    }
  end
end

local targets = {
  ["minecraft:emerald_ore"] = 0x46FF26AA,
  ["minecraft:diamond_ore"] = 0x50F8FFAA,
  ["minecraft:gold_ore"] = 0xFFDF50AA,
  ["minecraft:redstone_ore"] = 0xCC121566,
  ["minecraft:lit_redstone_ore"] = 0xCC121566,
  ["minecraft:iron_ore"] = 0xFFAC8766,
  ["minecraft:lapis_ore"] = 0x0A107F66,
  ["minecraft:coal_ore"] = 0x20202066,
  ["quark:biotite_ore"] = 0x02051C66,
  ["minecraft:quartz_ore"] = 0xCCCCCC66,
  ["minecraft:glowstone"] = 0xFFDFA166
}
local projecting = { }
local offset = getPoint() or error('GPS not found')
local canvas = modules.canvas3d().create()

local function update()
  while true do
    -- order matters
    local scanned = modules.scan()
    local pos = getPoint()

    if pos then
      if math.abs(pos.x - offset.x) +
         math.abs(pos.y - offset.y) +
         math.abs(pos.z - offset.z) > 64 then
        for _, b in pairs(projecting) do
          b.box.remove()
        end
        projecting = { }
        offset = pos
        canvas.recenter()
      end

      local blocks = { }
      for _, b in pairs(scanned) do
        if targets[b.name] then
          -- track block's world position
          b.id = table.concat({
            math.floor(pos.x + b.x),
            math.floor(pos.y + b.y),
            math.floor(pos.z + b.z) }, ':')
          blocks[b.id] = b
        end
      end

      for _, b in pairs(blocks) do
        if not projecting[b.id] then
          projecting[b.id] = b
          b.box = canvas.addBox(
            pos.x - offset.x + b.x + -(pos.x % 1) + .25,
            pos.y - offset.y + b.y + -(pos.y % 1) + .25,
            pos.z - offset.z + b.z + -(pos.z % 1) + .25,
            .5, .5, .5, targets[b.name])
          b.box.setDepthTested(false)
        end
      end

      for _, b in pairs(projecting) do
        if not blocks[b.id] then
          b.box.remove()
          projecting[b.id] = nil
        end
      end
    end

    os.sleep(.5)
  end
end

parallel.waitForAny(
  function()
    print('Ore visualization started')
    print('Press enter to exit')
    while true do
      local e, key = os.pullEventRaw('key')
      if key == keys.enter or e == 'terminate' then
        break
      end
    end
  end,
  update
)

canvas.clear()
