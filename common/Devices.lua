local Ansi  = require('opus.ansi')
local Event = require('opus.event')
local UI    = require('opus.ui')
local Util  = require('opus.util')

local device = _G.device

--[[ -- PeripheralsPage  -- ]] --
local peripheralsPage = UI.Page {
	grid = UI.ScrollingGrid {
		ey = -2,
		columns = {
			--{ heading = 'Name', key = 'name' },
			{ heading = 'Type', key = 'type' },
			{ heading = 'Side', key = 'side' },
		},
		sortColumn = 'type',
		autospace = true,
		enable = function(self)
			Util.clear(self.values)
			for _,v  in pairs(device) do
				table.insert(self.values, {
					type = v.type,
					side = v.side,
					name = v.name,
				})
			end
			self:update()
			self:adjustWidth()
			UI.Grid.enable(self)
		end,
	},
	statusBar = UI.StatusBar {
		values = 'Select peripheral',
	},
	accelerators = {
		[ 'control-q' ] = 'quit',
	},
	updatePeripherals = function(self)
		if UI:getCurrentPage() == self then
			self.grid:draw()
			self:sync()
		end
	end,
	eventHandler = function(self, event)
		if event.type == 'quit' then
			UI:quit()

		elseif event.type == 'grid_select' then
			UI:setPage('methods', event.selected)

		end
		return UI.Page.eventHandler(self, event)
	end,
}

--[[ -- MethodsPage  -- ]] --
local methodsPage = UI.Page {
	doc = UI.TextArea {
		backgroundColor = 'black',
		ey = -7,
		marginLeft = 1, marginTop = 1,
	},
	grid = UI.ScrollingGrid {
		y = -6, ey = -2,
		columns = {
			{ heading = 'Name', key = 'name' }
		},
		sortColumn = 'name',
	},
	statusBar = UI.StatusBar {
		status = 'q to return',
	},
	accelerators = {
		[ 'control-q' ] = 'back',
		backspace = 'back',
	},
	enable = function(self, p)
		self.peripheral = p or self.peripheral

		p = device[self.peripheral.name]
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
			for k,v in pairs(p) do
				if type(v) == 'function' then
					table.insert(self.grid.values, {
						name = k,
						noext = true,
					})
				end
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
	end,
}

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

UI:start()
