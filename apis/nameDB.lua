local JSON    = require('json')
local TableDB = require('tableDB')

local nameDB = TableDB()

function nameDB:load()

  local blocks = JSON.decodeFromFile('usr/etc/blocks.json')

  if not blocks then
    error('Unable to read usr/etc/blocks.json')
  end

  for strId, block in pairs(blocks) do
    local strId = 'minecraft:' .. strId
    if type(block.name) == 'string' then
      self.data[strId .. ':0'] = block.name
    else
      for nid,name in pairs(block.name) do
        self.data[strId .. ':' .. (nid-1)] = name
      end
    end
  end
end

function nameDB:getName(strId)
  return self.data[strId] or strId
end

nameDB:load()

return nameDB
