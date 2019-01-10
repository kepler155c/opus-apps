local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local context = Milo:getContext()

local manageTab = UI.Window {
  tabTitle = 'Manage',
  index = 1,
  form = UI.Form {
    x = 1, ex = -1, ey = -1,
    --manualControls = true,
    [1] = UI.TextEntry {
      formLabel = 'Name', formKey = 'displayName', help = 'Override display name',
      shadowText = 'Display name',
      required = true,
      limit = 120,
    },
    [2] = UI.TextEntry {
      width = 7,
      formLabel = 'Min', formKey = 'low', help = 'Craft if below min',
      validate = 'numeric',
    },
    [3] = UI.TextEntry {
      width = 7,
      formLabel = 'Max', formKey = 'limit', help = 'Send to trash if above max',
      validate = 'numeric',
    },
    [4] = UI.Checkbox {
      formLabel = 'Ignore Dmg', formKey = 'ignoreDamage',
      help = 'Ignore damage of item',
    },
    [5] = UI.Checkbox {
      formLabel = 'Ignore NBT', formKey = 'ignoreNbtHash',
      help = 'Ignore NBT of item',
    },
  },
}

function manageTab:setItem(item)
  self.origItem = item
  self.item = Util.shallowCopy(item)
  self.res = item.resource or { }
  self.res.displayName = self.item.displayName
  self.form:setValues(self.res)
end

function manageTab:eventHandler(event)
  if event.type == 'form_cancel' then
    UI:setPreviousPage()

  elseif event.type == 'form_complete' then
    local item = self.item

    if self.form:save() then
      if self.res.displayName ~= self.origItem.displayName then
        self.origItem.displayName = self.res.displayName
        itemDB:add(self.origItem)
        itemDB:flush()

        -- TODO: ugh
        if context.storage.cache[self.origItem.key] then
          context.storage.cache[self.origItem.key].displayName = self.res.displayName
        end
      end
      self.res.displayName = nil
      Util.prune(self.res, function(v)
        if type(v) == 'boolean' then
          return v
        elseif type(v) == 'string' then
          return #v > 0
        end
        return true
      end)

      local newKey = {
        name = item.name,
        damage = self.res.ignoreDamage and 0 or item.damage,
        nbtHash = not self.res.ignoreNbtHash and item.nbtHash or nil,
      }

      for k,v in pairs(context.resources) do
        if v == self.res then
          context.resources[k] = nil
          break
        end
      end

      if not Util.empty(self.res) then
        context.resources[Milo:uniqueKey(newKey)] = self.res
      end

      Milo:saveResources()
      UI:setPreviousPage()
    end
  else
    return
  end
  return true
end

return manageTab
