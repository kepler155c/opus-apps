--(c) 2013 Felix Maxwell
--License: CC BY-SA 3.0
--http://www.computercraft.info/forums2/index.php?/topic/12239-100-screensavers-game-of-life-and-matrix/

-- modified for use in Opus

local fps = 4 --Determines how long the program will wait between each tick
local char = "\127" --Live cells will look like this

local colors = _G.colors
local term   = _G.term

local function randomColor()
	return 2 ^ math.random(0, 14)
end

local function printCharAt( monitor, x, y, ch )
	monitor.setCursorPos( x, y )
	monitor.write( ch )
end

local function getNumNeighborhood( grid, x, y )
	local neighbors = 0
	if x > 1 then
		if y > 1 then
			if grid[x-1][y-1] == char then neighbors = neighbors + 1 end
		end
		if grid[x-1][y] == char then neighbors = neighbors + 1 end
		if y < #grid[x] then
			if grid[x-1][y+1] == char then neighbors = neighbors + 1 end
		end
	end

	if y > 1 then
		if grid[x][y-1] == char then neighbors = neighbors + 1 end
	end
	if y < #grid[x] then
		if grid[x][y+1] == char then neighbors = neighbors + 1 end
	end

	if x < #grid then
		if y > 1 then
			if grid[x+1][y-1] == char then neighbors = neighbors + 1 end
		end
		if grid[x+1][y] == char then neighbors = neighbors + 1 end
		if y < #grid then
			if grid[x+1][y+1] == char then neighbors = neighbors + 1 end
		end
	end

	return neighbors
end
local function lifeOrDeath( cur, neighbors )
	if neighbors < 2 then
		return " "
	elseif neighbors > 3 then
		return " "
	elseif neighbors == 3 then
		return char
	else
		return cur
	end
end

local function tick( monitor, grid )
	local retGrid = {}
	for x=1,#grid do
		retGrid[x] = {}
		for y=1,#grid[x] do
			local num = getNumNeighborhood( grid, x, y )
			retGrid[x][y] = lifeOrDeath( grid[x][y], num )
			if retGrid[x][y] ~= grid[x][y] then
				printCharAt( monitor, x, y, retGrid[x][y] )
			end
		end
	end
	return retGrid
end

local function setup( w, h )
	local grid = {}
	for i=1,w do
		grid[i] = {}
		for o=1,h do
			if math.random(1, 5) == 1 then
				grid[i][o] = char
			else
				grid[i][o] = " "
			end
		end
	end
	return grid
end

local function run()
	local monitor = term.current()
	if monitor.isColor() then
		monitor.setTextColor(colors.lime)
		monitor.setBackgroundColor(colors.black)
	end
	local w, h = monitor.getSize()
	local grid

	local delay = 1/fps
	local timerId = os.startTimer(delay)
	local reset = 0
	while true do
		local e, id = os.pullEvent()
		if e == 'key' or e == 'char' or e == 'mouse_click' then
			break
		end
		if e == 'timer' and id == timerId then
			if reset == 0 then
				reset = 300
				monitor.setTextColor(randomColor())
				grid = setup(w, h)
				monitor.clear()
			end
			reset = reset - 1
			grid = tick( monitor, grid )
			timerId = os.startTimer(delay)
		end
	end
end

run()
term.setCursorPos(1, 1)
term.clear()
