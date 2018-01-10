local JSON    = require('json')
local TableDB = require('tableDB')

local fs = _G.fs

local NAME_DIR = '/usr/etc/names'

local nameDB = TableDB()

function nameDB:load()

  local files = fs.list(NAME_DIR)
  table.sort(files)

  for _,file in ipairs(files) do
    local mod = file:match('(%S+).json')
    local blocks = JSON.decodeFromFile(fs.combine(NAME_DIR, file))

    if not blocks then
      error('Unable to read ' .. fs.combine(NAME_DIR, file))
    end

    for strId, block in pairs(blocks) do
      strId = string.format('%s:%s', mod, strId)
      if type(block.name) == 'string' then
        self.data[strId .. ':0'] = block.name
      else
        for nid,name in pairs(block.name) do
          self.data[strId .. ':' .. (nid-1)] = name
        end
      end
    end
  end
end

function nameDB:getName(strId)
  return self.data[strId] or strId
end

nameDB:load()

return nameDB
