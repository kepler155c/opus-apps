local Builder   = require('builder.builder')
local Schematic = require('builder.schematic')
local TableDB   = require('core.tableDB')
local Util      = require('opus.util')

local device    = _G.device
local fs        = _G.fs

local function Syntax(msg)
 print([[Required:
 * Neural Interface
 * Overlay glasses
 * Entity sensor
 * Introspection module
]])
	error(msg)
end

local neural = device['neuralInterface'] or Syntax('Must be run on a neural interface')

local function assertModule(module, name)
	if not neural.hasModule(module) then
		Syntax('Missing: ' .. name)
	end
end
assertModule('plethora:glasses', 'Overlay glasses')
assertModule('plethora:sensor', 'Entity sensor')
assertModule('plethora:introspection', 'Introspection module')

local BUILDER_DIR = 'usr/builder'

--[[-- SubDB --]]--
local subDB = TableDB({
	fileName = fs.combine(BUILDER_DIR, 'sub.db'),
})

function subDB:load()
	if fs.exists(self.fileName) then
		TableDB.load(self)
	elseif not Builder.isCommandComputer then
		self:seedDB()
	end
end

function subDB:seedDB()
	self.data = {
		[ "minecraft:redstone_wire:0"        ] = "minecraft:redstone:0",
		[ "minecraft:wall_sign:0"            ] = "minecraft:sign:0",
		[ "minecraft:standing_sign:0"        ] = "minecraft:sign:0",
		[ "minecraft:potatoes:0"             ] = "minecraft:potato:0",
		[ "minecraft:unlit_redstone_torch:0" ] = "minecraft:redstone_torch:0",
		[ "minecraft:powered_repeater:0"     ] = "minecraft:repeater:0",
		[ "minecraft:unpowered_repeater:0"   ] = "minecraft:repeater:0",
		[ "minecraft:carrots:0"              ] = "minecraft:carrot:0",
		[ "minecraft:cocoa:0"                ] = "minecraft:dye:3",
		[ "minecraft:unpowered_comparator:0" ] = "minecraft:comparator:0",
		[ "minecraft:powered_comparator:0"   ] = "minecraft:comparator:0",
		[ "minecraft:piston_head:0"          ] = "minecraft:air:0",
		[ "minecraft:piston_extension:0"     ] = "minecraft:air:0",
		[ "minecraft:portal:0"               ] = "minecraft:air:0",
		[ "minecraft:double_wooden_slab:0"   ] = "minecraft:planks:0",
		[ "minecraft:double_wooden_slab:1"   ] = "minecraft:planks:1",
		[ "minecraft:double_wooden_slab:2"   ] = "minecraft:planks:2",
		[ "minecraft:double_wooden_slab:3"   ] = "minecraft:planks:3",
		[ "minecraft:double_wooden_slab:4"   ] = "minecraft:planks:4",
		[ "minecraft:double_wooden_slab:5"   ] = "minecraft:planks:5",
		[ "minecraft:lit_redstone_lamp:0"    ] = "minecraft:redstone_lamp:0",
		[ "minecraft:double_stone_slab:1"    ] = "minecraft:sandstone:0",
		[ "minecraft:double_stone_slab:2"    ] = "minecraft:planks:0",
		[ "minecraft:double_stone_slab:3"    ] = "minecraft:cobblestone:0",
		[ "minecraft:double_stone_slab:4"    ] = "minecraft:brick_block:0",
		[ "minecraft:double_stone_slab:5"    ] = "minecraft:stonebrick:0",
		[ "minecraft:double_stone_slab:6"    ] = "minecraft:nether_brick:0",
		[ "minecraft:double_stone_slab:7"    ] = "minecraft:quartz_block:0",
		[ "minecraft:double_stone_slab:9"    ] = "minecraft:sandstone:2",
		[ "minecraft:double_stone_slab2:0"   ] = "minecraft:sandstone:0",
		[ "minecraft:stone_slab:2"           ] = "minecraft:wooden_slab:0",
		[ "minecraft:wheat:0"                ] = "minecraft:wheat_seeds:0",
		[ "minecraft:flowing_water:0"        ] = "minecraft:air:0",
		[ "minecraft:lit_furnace:0"          ] = "minecraft:furnace:0",
		[ "minecraft:wall_banner:0"          ] = "minecraft:banner:0",
		[ "minecraft:standing_banner:0"      ] = "minecraft:banner:0",
		[ "minecraft:tripwire:0"             ] = "minecraft:string:0",
		[ "minecraft:pumpkin_stem:0"         ] = "minecraft:pumpkin_seeds:0",
	}
	self.dirty = true
	self:flush()
end

function subDB:add(s)
	TableDB.add(self, { s.id, s.dmg }, table.concat({ s.sid, s.sdmg }, ':'))
	self:flush()
end

function subDB:remove(s)
	-- TODO: tableDB.remove should take table key
	TableDB.remove(self, s.id .. ':' .. s.dmg)
	self:flush()
end

function subDB:extract(s)
	local id, dmg = s:match('(.+):(%d+)')
	return id, tonumber(dmg)
end

function subDB:getSubstitutedItem(id, dmg)
	local sub = TableDB.get(self, { id, dmg })
	if sub then
		id, dmg = self:extract(sub)
	end
	return { id = id, dmg = dmg }
end

function subDB:lookupBlocksForSub(sid, sdmg)
	local t = { }
	for k,v in pairs(self.data) do
		local id, dmg = self:extract(v)
		if id == sid and dmg == sdmg then
			id, dmg = self:extract(k)
			t[k] = { id = id, dmg = dmg, sid = sid, sdmg = sdmg }
		end
	end
	return t
end

--[[-- startup logic --]]--
local args = {...}
if #args < 1 then
	error('supply file name')
end

subDB:load()

print('Loading schematic')
Builder.schematic = Schematic()
Builder.schematic:load(args[1])
print('Substituting blocks')

Builder.subDB = subDB
Builder:substituteBlocks(Util.throttle())

local cn = neural.canvas3d().create()
local pos = neural.getMetaOwner().withinBlock

cn.recenter({-pos.x + .5, -(pos.y + 2) + .5, -pos.z + .5 })

for i = 1, #Builder.schematic.blocks do
	local b = Builder.schematic:getComputedBlock(i)
	if b.id ~= "minecraft:air" and b.id ~= 'minecraft:water' then
		local s, m = pcall(function()
			cn.addItem({ b.x, b.y, b.z }, b.id, b.dmg)
		end)
		if not s and m then
			_G.printError(m)
		end
	end
end

pcall(_G.read)
cn.clear()
