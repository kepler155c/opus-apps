_G.requireInjector()

local itemDB = require('itemDB')
local json   = require('json')
local Util   = require('util')

local args = { ... }
local mod = args[1] or error('Syntax: namedb MOD')

--[[
  "double_plant": {
    "name": ["Sunflower",
      "Lilac",
      "Double Tallgrass",
      "Large Fern",
      "Rose Bush",
      "Peony"],
  },
--]]

local list = { }

for _,v in pairs(itemDB.data) do
	local t = Util.split(v.name, '(.-):')

	if t[1] == mod then
		local name = t[2]
		local damage = v.damage or 0
		local entry = list[name]
		if not entry then
			entry = { }
			list[name] = entry
		end
		if not entry.name and damage == 0 then
			entry.name = v.displayName
		else
			if not entry.name then
				entry.name = { }
			elseif type(entry.name) == 'string' then
				entry.name = { entry.name }
			end
			while #entry.name < damage do
				entry.name[#entry.name + 1] = ''
			end
			entry.name[damage + 1] = v.displayName
		end
	end
end

json.encodeToFile(string.format('usr/etc/names/%s.json', mod), list)
