local itemDB = require('core.itemDB')
local Map    = require('opus.map')
local Milo   = require('milo')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local context = Milo:getContext()

local manageTab = UI.Tab {
	title = 'Manage',
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
			transform = 'number',
		},
		[3] = UI.TextEntry {
			width = 7,
			formLabel = 'Max', formKey = 'limit', help = 'Send to trash if above max',
			transform = 'number',
		},
		[4] = UI.Checkbox {
			formLabel = 'Ignore NBT', formKey = 'ignoreNbt',
			help = 'Ignore NBT of item',
		},
	},
}

function manageTab:setItem(item)
	self.item = item
	self.res = Util.shallowCopy(context.resources[item.key] or { })
	self.res.displayName = self.item.displayName
	self.form:setValues(self.res)
end

function manageTab:eventHandler(event)
	if event.type == 'form_cancel' then
		UI:setPreviousPage()

	elseif event.type == 'form_complete' then
		if self.form:save() then
			if self.res.displayName ~= self.item.displayName then
				self.item.displayName = self.res.displayName
				itemDB:add(self.item)
				itemDB:flush()
				if context.storage.cache[self.item.key] then
					context.storage.cache[self.item.key].displayName = self.res.displayName
				end
				--context.storage:setDirty()
			end

			self.res.displayName = nil
			Map.prune(self.res, function(v)
				if type(v) == 'boolean' then
					return v
				elseif type(v) == 'string' then
					return #v > 0
				end
				return true
			end)

			local newKey = {
				name = self.item.name,
				nbt = not self.res.ignoreNbt and self.item.nbt or nil,
			}

			context.resources[self.item.key] = nil
			if not Util.empty(self.res) then
				context.resources[itemDB:makeKey(newKey)] = self.res
			end

			Milo:saveResources()
			UI:setPreviousPage()
		end
	else
		return
	end
	return true
end

return { itemTab = manageTab }
