--Same Game for CraftOS 1.0.0 (ShinyCube) (Advanced Computer)

-- slight modifications to run on a kiosk
local score, A, B, C, D, E
local board = {}
local selected = {}
local backup_board = {}
local backup_score
local backup_exists = false
local cnt_selected
local selected_color
local is_gameover
local best_scores = {}
local best_score_names = {}
local best_score_view = false
function init()
	loadScore()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	for i = 1, 10 do
		board[i] = {}
		selected[i] = {}
		backup_board[i] = {}
	end
	newGame()
	eventLoop()
end
function eventLoop()
	while true do
		local event, button, x, y = os.pullEvent()
		if event == "mouse_click" then
			if best_score_view then
				if y == 1 and 44 <= x and x <= 51 then
					best_score_view = false
					redraw()
				end
			else
				if x >= 7 and x <= 46 and y >=8 and y <= 17 then
					local j = math.floor((x-7)/2) + 1
					local i = (y-8) + 1
					clicked(i,j)
				end
				if y == 1 and 1 <= x and x <= 7 then
					newGame()
				end
				if y == 1 and 9 <= x and x <= 16 then
					undo()
					redraw()
				end
				if y == 1 and 18 <= x and x <= 31 then
					showBestScore()
				end
				if y == 1 and 33 <= x and x <= 42 then
					redraw()
				end
				if y == 1 and 44 <= x and x <= 51 then
					term.clear()
					term.setCursorPos(1,1)
					break
				end
			end
		end
	end
end
function newGame()
	score = 0
	A = 0
	B = 0
	C = 0
	D = 0
	E = 0
	cnt_selected = 0
	is_gameover = false
	backup_exists = false
	for i = 1, 10 do
		for j = 1, 20 do
			board[i][j] = math.random(5)
			if(board[i][j] == 1) then A = A + 1 end
			if(board[i][j] == 2) then B = B + 1 end
			if(board[i][j] == 3) then C = C + 1 end
			if(board[i][j] == 4) then D = D + 1 end
			if(board[i][j] == 5) then E = E + 1 end
			selected[i][j] = false
		end
	end
	redraw()
end
function redraw()
	if best_score_view then
		term.setCursorPos(1,1) term.write("                                           [ BACK ]")
	else
		term.setCursorPos(1,1) term.write("[ NEW ] [ UNDO ] [ HIGH SCORE ] [ SCREEN ] [ EXIT ]")
	end
	term.setCursorPos(16,3) term.write("Same Game for Craft OS")
	term.setCursorPos(15,5) term.write("Implemented by ShinyCube")
	term.setCursorPos(3,19) term.write("Score:            A:    B:    C:    D:    E:   ")
	if best_score_view then
		for i = 1, 10 do
			term.setTextColor(colors.white)
			term.setBackgroundColor(colors.black)
			term.setCursorPos(7,8+(i-1))
			term.write(string.format("%2d. ...............................%5d",i,best_scores[i]))
			term.setCursorPos(11,8+(i-1))
			term.write(best_score_names[i])
		end
	else
		for i = 1, 10 do
			for j = 1, 20 do
				term.setCursorPos(7+(j-1)*2,8+(i-1))
				if board[i][j] == 0 then
					term.blit(". ","00","ff")
				elseif board[i][j] == 1 then
					if selected[i][j] then
						term.blit("A ","aa","00")
					else
						term.blit("A ","00","aa")
					end
				elseif board[i][j] == 2 then
					if selected[i][j] then
						term.blit("B ","bb","00")
					else
						term.blit("B ","00","bb")
					end
				elseif board[i][j] == 3 then
					if selected[i][j] then
						term.blit("C ","cc","00")
					else
						term.blit("C ","00","cc")
					end
				elseif board[i][j] == 4 then
					if selected[i][j] then
						term.blit("D ","dd","00")
					else
						term.blit("D ","00","dd")
					end
				elseif board[i][j] == 5 then
					if selected[i][j] then
						term.blit("E ","ee","00")
					else
						term.blit("E ","00","ee")
					end
				end
			end
		end
	end
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.setCursorPos(22,7)
	if is_gameover then
		term.write("GAME OVER")
	else
		term.write("         ")
	end
	term.setCursorPos(9,19)
	term.write("           ")
	term.setCursorPos(9,19)
	term.write(score)
	if cnt_selected > 0 then
		term.write("+" .. cnt_selected*cnt_selected-3*cnt_selected+4)
	end
	term.setCursorPos(23,19)
	term.write(A)
	term.setCursorPos(29,19)
	term.write(B)
	term.setCursorPos(35,19)
	term.write(C)
	term.setCursorPos(41,19)
	term.write(D)
	term.setCursorPos(47,19)
	term.write(E)
end
function deselectAll()
	for i = 1, 10 do
		for j = 1, 20 do
			selected[i][j] = false
		end
	end
	cnt_selected = 0
end
function rec_selection(i,j)
	if not selected[i][j] then
		selected[i][j] = true
		cnt_selected = cnt_selected + 1
		if i-1 >= 1 and board[i][j] == board[i-1][j] then rec_selection(i-1,j) end
		if i+1 <= 10 and board[i][j] == board[i+1][j] then rec_selection(i+1,j) end
		if j-1 >= 1 and board[i][j] == board[i][j-1] then rec_selection(i,j-1) end
		if j+1 <= 20 and board[i][j] == board[i][j+1] then rec_selection(i,j+1) end
	end
end
function backup()
	for i = 1, 10 do
		for j = 1, 20 do
			backup_board[i][j] = board[i][j]
			backup_score = score
		end
	end
	backup_exists = true
end
function removeSelected()
	local di, dj
	dj = 1
	for sj = 1, 20 do
		di = 10
		for si = 10, 1, -1 do
			if not selected[si][sj] then
				board[di][dj] = board[si][sj]
				di = di - 1
			end
		end
		for di = di, 1, -1 do
			board[di][dj] = 0
		end
		if board[10][dj] ~= 0 then dj = dj + 1 end
	end
	for dj = dj, 20 do
		for di = 1, 10 do
			board[di][dj] = 0
		end
	end
end
function checkGameOver()
	for i = 1, 10 do
		for j = 1, 20 do
			if i-1>=1 and board[i][j] > 0 and board[i][j] == board[i-1][j] then return false end
			if i+1<=10 and board[i][j] > 0 and board[i][j] == board[i+1][j] then return false end
			if j-1>=1 and board[i][j] > 0 and board[i][j] == board[i][j-1] then return false end
			if j+1<=20 and board[i][j] > 0 and board[i][j] == board[i][j+1] then return false end
		end
	end
	return true
end
function loadScore()
	local file = fs.open("same.dat","r")
	if file then
		for i = 1, 10 do
			best_score_names[i] = file.readLine() or "NONAME"
			best_scores[i] = tonumber(file.readLine()) or 0
		end
		file.close()
	else
		for i = 1, 10 do
			best_score_names[i] = "NONAME"
			best_scores[i] = 0
		end
	end
end
function saveScore()
	local file = fs.open("same.dat","w")
	if file then
		for i = 1, 10 do
			file.writeLine(best_score_names[i])
			file.writeLine(best_scores[i])
		end
		file.flush()
	end
end
function updateScore()
	local rank = 1
	for i = 10, 1, -1 do
		if best_scores[i] < score then
			best_score_names[i+1] = best_score_names[i]
			best_scores[i+1] = best_scores[i]
		else
			rank = i + 1
			break
		end
	end
	if rank <= 10 then
		best_score_names[rank] = getName(rank, score)
		best_scores[rank] = score
		saveScore()
		best_score_view = true
		redraw()
	end
end
function getName(rank, score)
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.clear()
	term.setCursorPos(1,1)
	print("Congratulation!")
	print("You got a high score!")
	print("Your score: " .. score)
	print("Your rank: " .. rank)
	print("Type your name. >")
	local name = '...'
	name = string.sub(name, 1, 30)
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.clear()
	return name
end
function undo()
	if backup_exists then
		deselectAll()
		backup_exists = false
		score = backup_score
		for i = 1, 10 do
			for j = 1, 20 do
				board[i][j] = backup_board[i][j]
			end
		end
	end
end
function showBestScore()
	best_score_view = true
	redraw()
end

function clicked(ci,cj)
	if selected[ci][cj] then
		backup()
		score = score + cnt_selected*cnt_selected-3*cnt_selected+4
		if selected_color == 1 then A = A - cnt_selected
		elseif selected_color == 2 then B = B - cnt_selected
		elseif selected_color == 3 then C = C - cnt_selected
		elseif selected_color == 4 then D = D - cnt_selected
		elseif selected_color == 5 then E = E - cnt_selected
		end
		removeSelected()
		deselectAll()
		if checkGameOver() then
			is_gameover = true
			backup_exists = false
			updateScore()
			redraw()
		else
			redraw()
		end
	else
		if cnt_selected > 0 then
			deselectAll()
			redraw()
		else
			if board[ci][cj] > 0 then
				selected_color = board[ci][cj]
				rec_selection(ci,cj)
				if cnt_selected == 1 then
					deselectAll()
				end
				redraw()
			end
		end
	end
end
init()