local Blocks    = require('blocks')
local Message   = require('message')
local Util      = require('util')

local device     = _G.device
local fs         = _G.fs
local turtle     = _G.turtle

local Builder = {
  isCommandComputer = not turtle,
  slots = { },
  loc = { },
  index = 1,
  mode = 'build',
  fuelItem = { id = 'minecraft:coal', dmg = 0 },
  resourceSlots = 14,
  facing = 'south',
  wrenchSucks = false,
  stairBug = false,
}

local BUILDER_DIR = 'usr/builder'

local blockInfo = Blocks()

function Builder:getBlockCounts()
  local blocks = { }

  -- add a couple essential items to the supply list to allow replacements
  if not self.isCommandComputer then
    local wrench = self.subDB:getSubstitutedItem('SubstituteAWrench', 0)
    wrench.qty = 0
    wrench.need = 1
    blocks[wrench.id .. ':' .. wrench.dmg] = wrench

    local fuel = self.subDB:getSubstitutedItem(Builder.fuelItem.id, Builder.fuelItem.dmg)
    fuel.qty = 0
    fuel.need = 1
    blocks[fuel.id .. ':' .. fuel.dmg] = fuel

    blocks['minecraft:piston:0'] = {
      id = 'minecraft:piston',
      dmg = 0,
      qty = 0,
      need = 1,
    }
  end

  for k = self.index, #self.schematic.blocks do
    local b = self.schematic.blocks[k]
    local key = tostring(b.id) .. ':' .. b.dmg
    local block = blocks[key]
    if not block then
      block = Util.shallowCopy(b)
      block.qty = 0
      block.need = 0
      blocks[key] = block
    end
    block.need = block.need + 1
  end

  return blocks
end

function Builder:substituteBlocks(throttle)
  for _,b in pairs(self.schematic.blocks) do

    -- replace schematic block type with substitution
    local pb = blockInfo:getPlaceableBlock(b.id, b.dmg)

    Util.merge(b, pb)

    b.odmg = pb.odmg or pb.dmg

    local sub = self.subDB:get({ b.id, b.dmg })
    if sub then
      b.id, b.dmg = self.subDB:extract(sub)
    end
    throttle()
  end
end

function Builder:reloadSchematic(throttle)
  self.schematic:reload(throttle)
  self:substituteBlocks(throttle)
end

function Builder:log(...)
  Util.print(...)
end

function Builder:dumpInventory()
end

function Builder:logBlock(index, b)
  local bdir = b.direction or ''
  local logText = string.format('%d %s:%d (x:%d,z:%d:y:%d) %s',
    index, b.id, b.dmg, b.x, b.z, b.y, bdir)
  self:log(logText)
  -- self:log(b.index) -- unique identifier of block

  if device.wireless_modem then
    Message.broadcast('builder', { x = b.x, y = b.y, z = b.z, heading = b.heading })
  end
end

function Builder:saveProgress(index)
  Util.writeTable(
    fs.combine(BUILDER_DIR, self.schematic.filename .. '.progress'),
    { index = index, facing = Builder.facing, loc = Builder.loc }
  )
end

function Builder:loadProgress(filename)
  local progress = Util.readTable(fs.combine(BUILDER_DIR, filename))
  if progress then
    Builder.index = progress.index
    if Builder.index > #self.schematic.blocks then
      Builder.index = 1
    end
    Builder.facing = progress.facing or 'south'
    Builder.loc = progress.loc or { }
  end
end

return Builder
