local Milo   = require('milo')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local context = Milo:getContext()

local page = UI.Page {
	titleBar = UI.TitleBar {
		title = 'Item settings',
		previousPage = true,
	},
	statusBar = UI.StatusBar { },
	notification = UI.Notification { },
}

function page:enable(item)
	if not self.tabs then
		table.sort(context.plugins.itemTab, function(a, b) return a.index < b.index end)
		local t = Util.shallowCopy(context.plugins.itemTab)
		t.y = 2
		t.ey = -2

		self:add({ tabs = UI.Tabs(t) })
	end

	for _, v in pairs(context.plugins.itemTab) do
		if v.UIElement then
			v:setItem(item)
		end
	end
	self.tabs:selectTab(context.plugins.itemTab[1])
	UI.Page.enable(self)
end

function page:eventHandler(event)
	if event.type == 'tab_activate' then
		event.activated:focusFirst()

	elseif event.type == 'form_invalid' then
		self.notification:error(event.message)

	elseif event.type == 'focus_change' then
		self.statusBar:setStatus(event.focused.help)
		self.statusBar:draw()

	elseif event.type == 'success_message' then
		self.notification:success(event.message)

	elseif event.type == 'info_message' then
		self.notification:info(event.message)

	elseif event.type == 'error_message' then
		self.notification:error(event.message)

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

UI:addPage('item', page)
