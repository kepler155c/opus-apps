local Event  = require('opus.event')
local itemDB = require('core.itemDB')
local neural = require('neural.interface')
local UI     = require('opus.ui')
local Util   = require('opus.util')

local device     = _G.device

neural.assertModules({
	'plethora:sensor',
	'plethora:kinetic',
	'plethora:introspection',
})
UI:configure('Equipment', ...)

local equipment = device.neuralInterface.getEquipment()

local slots = {
    'primary',
    'offhand',
    'boots',
    'leggings',
    'chest',
    'helmet',
}

local page = UI.Page {
	menuBar = UI.MenuBar {
		buttons = {
			{ text = 'Drop',    event = 'drop' },
			{ text = 'Suck',    event = 'suck' },
		},
	},
	grid = UI.Grid {
		y = 2,
		columns = {
            { heading = 'Slot', key = 'index', width = 7 },
			{ heading = 'Name',  key = 'displayName' },
			{ heading = 'Count', key = 'count', width = 5, align = 'right' },
		},
        sortColumn = 'index',
        accelerators = {
            grid_select = 'show_detail',
        },
        getDisplayValues = function(_, row)
            row = Util.shallowCopy(row)
            if row.name then
                local item = itemDB:get(
                    table.concat({ row.name, row.damage, row.nbtHash }, ':'),
                    function()
                        return equipment.getItemMeta(row.index)
                    end)
                row.displayName = item.displayName
            else
                row.displayName = 'empty'
            end
            row.index = slots[row.index]
            return row
        end,
	},
	accelerators = {
		[ 'control-q' ] = 'quit',
	},
	detail = UI.SlideOut {
		menuBar = UI.MenuBar {
			buttons = {
				{ text = 'Back', event = 'slide_hide'  },
			},
		},
		grid = UI.ScrollingGrid {
			y = 2,
			columns = {
				{ heading = 'Name', key = 'name' },
				{ heading = 'Value',  key = 'value' },
			},
			sortColumn = 'name',
			accelerators = {
				grid_select = 'inspect',
			},
        },
        show = function(self, slot)
            local detail = equipment.getItemMeta(slot.index)
            local t = { }
            for k,v in pairs(detail) do
                table.insert(t, {
                    name = k,
                    value = v,
                })
            end
            self.grid:setValues(t)
            self.grid:setIndex(1)
            UI.SlideOut.show(self)
        end,
    },
    enable = function(self)
        self:refresh()
        UI.Page.enable(self)
    end,
    refresh = function(self)
        local t = { }
        local list = equipment.list()
        for i = 1, equipment.size() do
            local v = list[i] or { }
            v.index = i
            table.insert(t, v)
        end
        self.grid:setValues(t)
        self.grid:draw()
    end,
    eventHandler = function(self, event)
        if event.type == 'quit' then
            UI:quit()

        elseif event.type == 'show_detail' then
            if event.selected.name then
                self.detail:show(event.selected)
            end

        elseif event.type == 'drop' then
            local selected = self.grid:getSelected()
            equipment.drop(selected.index)
            self:refresh()

        elseif event.type == 'suck' then
            local selected = self.grid:getSelected()
            equipment.suck(selected.index)
            self:refresh()
        end

        UI.Page.eventHandler(self, event)
    end,
}

Event.onInterval(1, function()
	page:refresh()
	page:sync()
end)

UI:setPage(page)
UI:start()

itemDB:flush()
