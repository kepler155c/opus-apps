_G.requireInjector(_ENV)

local Ansi  = require('opus.ansi')
local Event = require('opus.event')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local colors = _G.colors
local peripheral = _G.peripheral

--[[ -- PeripheralsPage  -- ]] --
local peripheralsPage = UI.Page {
	grid = UI.ScrollingGrid {
		ey = -2,
		columns = {
			{ heading = 'Type', key = 'type' },
			{ heading = 'Side', key = 'side' },
		},
		sortColumn = 'type',
		autospace = true,
	},
	statusBar = UI.StatusBar {
		values = 'Select peripheral',
	},
	accelerators = {
		q = 'quit',
	},
}

function peripheralsPage.grid:draw()
	local sides = peripheral.getNames()

	Util.clear(self.values)
	for _,side in pairs(sides) do
		table.insert(self.values, {
			type = peripheral.getType(side),
			side = side
		})
	end
	self:update()
	self:adjustWidth()
	UI.Grid.draw(self)
end

function peripheralsPage:updatePeripherals()
	if UI:getCurrentPage() == self then
		self.grid:draw()
		self:sync()
	end
end

function peripheralsPage:eventHandler(event)
	if event.type == 'quit' then
		Event.exitPullEvents()

	elseif event.type == 'grid_select' then
		UI:setPage('methods', event.selected)

	end
	return UI.Page.eventHandler(self, event)
end

--[[ -- MethodsPage  -- ]] --
local methodsPage = UI.Page {
	backgroundColor = colors.black,
	doc = UI.TextArea {
		backgroundColor = colors.black,
		x = 2, y = 2, ex = -1, ey = -7,
	},
	grid = UI.ScrollingGrid {
		y = -6, ey = -2,
		columns = {
			{ heading = 'Name', key = 'name', width = UI.term.width }
		},
		sortColumn = 'name',
	},
	statusBar = UI.StatusBar {
		status = 'q to return',
	},
	accelerators = {
		q = 'back',
		backspace = 'back',
	},
}

function methodsPage:enable(p)

	self.peripheral = p or self.peripheral

	p = peripheral.wrap(self.peripheral.side)
	if p.getDocs then
		-- plethora
		self.grid.values = { }
		for k,v in pairs(p.getDocs()) do
			table.insert(self.grid.values, {
				name = k,
				doc = v,
			})
		end
	elseif not p.getAdvancedMethodsData then
		-- computercraft
		self.grid.values = { }
		for name in pairs(p) do
			table.insert(self.grid.values, {
				name = name,
				noext = true,
			})
		end
	else
		-- open peripherals
		self.grid.values = p.getAdvancedMethodsData()
		for name,f in pairs(self.grid.values) do
			f.name = name
		end
	end

	self.grid:update()
	self.grid:setIndex(1)

	self.doc:setText(self:getDocumentation())

	self.statusBar:setStatus(self.peripheral.type)
	UI.Page.enable(self)

	self:setFocus(self.grid)
end

function methodsPage:eventHandler(event)
	if event.type == 'back' then
		UI:setPage(peripheralsPage)
		return true
	elseif event.type == 'grid_focus_row' then
		self.doc:setText(self:getDocumentation())
	end
	return UI.Page.eventHandler(self, event)
end

function methodsPage:getDocumentation()

	local method = self.grid:getSelected()

	if method.noext then    -- computercraft docs
		return 'No documentation'
	end

	if method.doc then      -- plethora docs
		return Ansi.yellow .. method.doc
	end

	-- open peripherals docs
	local sb = { }
	if method.description then
		table.insert(sb, method.description .. '\n\n')
	end

	if method.returnTypes ~= '()' then
		table.insert(sb, Ansi.yellow .. method.returnTypes .. ' ')
	end
	table.insert(sb, Ansi.blue .. method.name .. Ansi.reset .. '(')

	for k,arg in ipairs(method.args) do
		if arg.optional then
			table.insert(sb, Ansi.orange .. string.format('[%s]', arg.name))
		else
			table.insert(sb, Ansi.green .. arg.name)
		end
		if k < #method.args then
			table.insert(sb, ',')
		end
	end
	table.insert(sb, Ansi.reset .. ')')

	Util.filterInplace(method.args, function(a) return #a.description > 0 end)
	if #method.args > 0 then
		table.insert(sb, '\n\n')
		for k,arg in ipairs(method.args) do
			if arg.optional then
				table.insert(sb, Ansi.orange)
			else
				table.insert(sb, Ansi.green)
			end
			table.insert(sb, arg.name .. Ansi.reset .. ': ' .. arg.description)
			if k ~= #method.args then
				table.insert(sb, '\n\n')
			end
		end
	end
	return table.concat(sb)
end

Event.on('peripheral', function()
	peripheralsPage:updatePeripherals()
end)

Event.on('peripheral_detach', function()
	peripheralsPage:updatePeripherals()
end)

UI:setPage(peripheralsPage)

UI:setPages({
	methods = methodsPage,
})

UI:pullEvents()
