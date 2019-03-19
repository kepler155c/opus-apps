local gps        = _G.gps
local keys       = _G.keys
local os         = _G.os
local parallel   = _G.parallel
local peripheral = _G.peripheral

local modules = peripheral.find('neuralInterface')
if not modules then
  error('Plethora scanner must be equipped')
elseif not modules.canvas then
  error('Overlay glasses module is required')
elseif not modules.scan then
  error('Scanner module is required')
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

local function getPoint()
	local pt = { gps.locate() }
	return {
		x = pt[1],
		y = pt[2],
		z = pt[3],
	}
end

local offset = getPoint()
local canvas = modules.canvas3d().create()

local function run()
  while true do

    -- order matters
    local scanned = modules.scan()
    local pos = getPoint()

    local blocks = { }
    for _, b in pairs(scanned) do
      if targets[b.name] then
        b.wx = math.floor(pos.x + b.x)
        b.wy = math.floor(pos.y + b.y)
        b.wz = math.floor(pos.z + b.z)
        b.id = table.concat({ math.floor(b.wx), math.floor(b.wy), math.floor(b.wz) }, ':')
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
        projecting[b.id].box.remove()
        projecting[b.id] = nil
      end
    end

    if math.abs(pos.x - offset.x) +
       math.abs(pos.y - offset.y) +
       math.abs(pos.z - offset.z) > 64 then
      for _, b in pairs(projecting) do
        projecting[b.id].box.remove()
        projecting[b.id] = nil
      end
      offset = pos
      canvas.recenter()
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
  run
)

canvas:clear()
