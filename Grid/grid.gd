extends Node2D

# State Machine
enum {wait, move, win, booster}
var state

# Grid Variables
var width
var height
export (int) var x_start
export (int) var y_start
export (int) var offset
export (int) var y_offset

# Obstacle Stuff
export (PoolVector2Array) var empty_spaces

# Preset Board
export (PoolVector3Array) var preset_spaces

export (PoolStringArray) var possible_pieces

# hint stuff
export (PackedScene) var hint_effect
var hint = null
var match_c = ""

# The current pieces in the scene
var all_pieces = []
var clone_array = []
var current_matches = []

# Swap Back Variables
var piece_one = null
var piece_two = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)
var move_checked = false

# Touch Variables
var first_touch = Vector2(0, 0)
var final_touch = Vector2(0, 0)
var controlling = false

# Scoring Variables
var streak = 1

# Goal Check Stuff
signal check_goal


#Booster Stuff
var current_booster_type = ""

var Game

func _ready():
	Game = get_node("..")
	width = Game.width
	height = Game.height
	state = move
	randomize()
	all_pieces = make_2d_array()
	clone_array = make_2d_array()
	#empty_spaces = Global.levels[Global.current_level].empty.duplicate(true)
	spawn_preset_pieces()
	spawn_pieces()

func restricted_fill(place):
	# Check the empty pieces
	if is_in_array(empty_spaces, place):
		return true
	return false

func restricted_move(place):
	if is_in_array(empty_spaces, place):
		return true
	return false

func is_in_array(array, item):
	if array != null:
		for i in array.size():
			if array[i] == item:
				return true
	return false

func remove_from_array(array, item):
	for i in range(array.size() - 1, -1, -1):
		if array[i] == item:
			array.remove(i)

func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

func spawn_pieces():
	#empty_spaces = Global.levels[Global.current_level].empty.duplicate(true)
	for i in width:
		for j in height:
			if !restricted_fill(Vector2(i,j)) and all_pieces[i][j] == null:
				#choose a random number and store it
				var rand = floor(rand_range(0, possible_pieces.size()))
				var piece = load(possible_pieces[rand]).instance()
				var loops = 0
				while(match_at(i, j, piece.piece) && loops < 100):
					rand = floor(rand_range(0, possible_pieces.size()))
					loops += 1
					piece = load(possible_pieces[rand]).instance()
				# Instance that piece from the array
				
				add_child(piece)
				piece.position = grid_to_pixel(i, j)
				all_pieces[i][j] = piece
				all_pieces[i][j].grid = Vector2(i,j)
	if is_deadlocked():
		shuffle_board()
	$HintTimer.start()

# This needs to be fixed
func spawn_preset_pieces():
	if preset_spaces != null:
		if preset_spaces.size() > 0:
			for i in preset_spaces.size():
				var piece = possible_pieces[preset_spaces[i].z].instance()
				add_child(piece)
				piece.position = grid_to_pixel(preset_spaces[i].x, preset_spaces[i].y)
				all_pieces[preset_spaces[i].x][preset_spaces[i].y] = piece

func match_at(i, j, piece):
	if i > 1:
		if all_pieces[i - 1][j] != null && all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].piece == piece && all_pieces[i - 2][j].piece == piece:
				return true
	if j > 1:
		if all_pieces[i][j-1] != null && all_pieces[i][j-2] != null:
			if all_pieces[i ][j-1].piece == piece && all_pieces[i][j-2].piece == piece:
				return true

func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)

func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)
	pass

func is_in_grid(grid_position):
	if grid_position.x >= 0 && grid_position.x < width:
		if grid_position.y >= 0 && grid_position.y < height:
			return true
	return false

func touch_input():
	if Input.is_action_just_pressed("ui_touch"):
		get_node("../Touch").play()
		if is_in_grid(pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)):
			first_touch = pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
			all_pieces[first_touch.x][first_touch.y].selected = true
			all_pieces[first_touch.x][first_touch.y].animate(28)
			controlling = true
			if hint:
				hint.queue_free()
				hint = null
	if Input.is_action_just_released("ui_touch"):
		get_node("../Move").play()
		if is_in_grid(pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)) && controlling:
			controlling = false
			all_pieces[first_touch.x][first_touch.y].selected = false
			final_touch = pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
			touch_difference(first_touch, final_touch)

func swap_pieces(column, row, direction):
	var first_piece = all_pieces[column][row]
	var other_piece = all_pieces[column + direction.x][row + direction.y]
	if first_piece != null && other_piece != null:
		if !restricted_move(Vector2(column, row)) and !restricted_move(Vector2(column, row) + direction):
			if first_piece.piece == "Color" and other_piece.piece == "Color":
				clear_board()
			store_info(first_piece, other_piece, Vector2(column, row), direction)
			state = wait
			all_pieces[column][row] = other_piece
			all_pieces[column + direction.x][row + direction.y] = first_piece
			first_piece.move(grid_to_pixel(column + direction.x, row + direction.y))
			other_piece.move(grid_to_pixel(column, row))
			if !move_checked:
				find_matches()


func store_info(first_piece, other_piece, place, direction):
	piece_one = first_piece
	piece_two = other_piece
	last_place = place
	last_direction = direction
	pass

func swap_back():
	get_node("../SwapBack").play()
	# Move the previously swapped pieces back to the previous place.
	if piece_one != null && piece_two != null:
		swap_pieces(last_place.x, last_place.y, last_direction) 
	state = move
	move_checked = false
	$HintTimer.start()

func touch_difference(grid_1, grid_2):
	var difference = grid_2 - grid_1
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(1, 0))
		elif difference.x < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(-1, 0))
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, 1))
		elif difference.y < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, -1))

func _process(_delta):
	if state == move:
		touch_input()
	elif state == booster:
		booster_input()

func find_matches(query = false, array = all_pieces):
	for i in width:
		for j in height:
			if array[i][j] != null:
				var current_piece = array[i][j].piece
				if i > 0 && i < width - 1:
					if array[i-1][j] != null && array[i+1][j] != null:
						if array[i - 1][j].piece == current_piece && array[i + 1][j].piece == current_piece:
							if query:
								match_c = current_piece
								return true
							match_and_dim(array[i-1][j])
							match_and_dim(array[i][j])
							match_and_dim(array[i+1][j])
							add_to_array(Vector2(i, j))
							add_to_array(Vector2(i + 1, j))
							add_to_array(Vector2(i - 1, j))
				if j > 0 && j < height - 1:
					if array[i][j-1] != null && array[i][j + 1] != null:
						if array[i][j - 1].piece == current_piece && array[i][j + 1].piece == current_piece:
							if query:
								match_c = current_piece
								return true
							match_and_dim(array[i][j - 1])
							match_and_dim(array[i][j])
							match_and_dim(array[i][j + 1])
							add_to_array(Vector2(i, j))
							add_to_array(Vector2(i, j + 1))
							add_to_array(Vector2(i, j - 1))
	if query:
		return false
	get_parent().get_node("DestroyTimer").start()

func add_to_array(value, array_to_add = current_matches):
	if !array_to_add.has(value):
		array_to_add.append(value)

func is_piece_null(column, row, array = all_pieces):
	if array[column][row] == null:
		return true
	return false

func match_and_dim(item):
	item.matched = true



func destroy_matched():
	var was_matched = false
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					emit_signal("check_goal", all_pieces[i][j].piece)
					was_matched = true
					all_pieces[i][j].die()
					get_node("../Die").play()
					all_pieces[i][j] = null
					Global.change_score(streak)
	move_checked = true
	if was_matched:
		destroy_hint()
		get_parent().get_node("CollapseTimer").start()
	else:
		swap_back()
	current_matches.clear()

func make_effect(effect, column, row):
	var current = effect.instance()
	current.position = grid_to_pixel(column, row)
	current.grid = Vector2(column,row)
	add_child(current)


func match_color(piece):
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].piece == piece:
					match_and_dim(all_pieces[i][j])
					add_to_array(Vector2(i,j))

func clear_board():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				match_and_dim(all_pieces[i][j])
				add_to_array(Vector2(i,j))

func collapse_columns():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null && !restricted_fill(Vector2(i,j)):
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						all_pieces[i][k].move(grid_to_pixel(i, j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][j].grid = Vector2(i,j)
						all_pieces[i][k] = null
						break
	get_parent().get_node("RefillTimer").start()

func refill_columns():
	streak += 1
	for i in width:
		for j in height:
			if all_pieces[i][j] == null && !restricted_fill(Vector2(i,j)):
				#choose a random number and store it
				var rand = floor(rand_range(0, possible_pieces.size()))
				var piece = load(possible_pieces[rand]).instance()
				var loops = 0
				while(match_at(i, j, piece.piece) && loops < 100):
					rand = floor(rand_range(0, possible_pieces.size()))
					loops += 1
					piece = load(possible_pieces[rand]).instance()
				# Instance that piece from the array
				add_child(piece)
				piece.position = grid_to_pixel(i, j + y_offset)
				piece.move(grid_to_pixel(i,j))
				all_pieces[i][j] = piece
				all_pieces[i][j].grid = Vector2(i,j)
	after_refill()

func after_refill():
	get_node("../Spawn").play()
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if match_at(i, j, all_pieces[i][j].piece) or all_pieces[i][j].matched:
					find_matches()
					get_parent().get_node("DestroyTimer").start()
					return
	streak = 1
	move_checked = false
	if is_deadlocked():
		shuffle_board()
	"""
	if is_moves:
		if state != win:
			current_counter_value -= 1
			emit_signal("update_counter")
			if current_counter_value == 0:
				declare_game_over()
			else:
				state = move
	"""
	Global.change_moves(-1)
	state = move
	$HintTimer.start()



func find_normal_neighbor(column, row):
	# Check Right first
	if is_in_grid(Vector2(column + 1, row)):
		if all_pieces[column + 1][row] != null:
			return Vector2(column + 1, row)
	# Check Left
	elif is_in_grid(Vector2(column - 1, row)):
		if all_pieces[column - 1][row] != null:
			return Vector2(column - 1, row)
	# Check up
	elif is_in_grid(Vector2(column, row + 1)):
		if all_pieces[column][row + 1] != null:
			return Vector2(column, row + 1)
	# Check Down
	elif is_in_grid(Vector2(column, row -1)):
		if all_pieces[column][row-1] != null:
			return Vector2(column, row-1)
	return null

func match_all_in_column(column):
	for i in height:
		if all_pieces[column][i] != null:
			all_pieces[column][i].matched = true

func match_all_in_row(row):
	for i in width:
		if all_pieces[i][row] != null:
			all_pieces[i][row].matched = true

func find_adjacent_pieces(column, row):
	for i in range(-1, 2):
		for j in range(-1, 2):
			if is_in_grid(Vector2(column + i, row + j)):
				if all_pieces[column + i][row + j] != null:
					all_pieces[column + i][row + j].matched = true

func switch_pieces(place, direction, array):
	if is_in_grid(place) and !restricted_fill(place):
		if is_in_grid(place + direction) and !restricted_fill(place + direction):
			# First, hold the piece to swap with
			var holder = array[place.x + direction.x][place.y + direction.y]
			# Then set the swap spot as the original piece
			array[place.x + direction.x][place.y + direction.y] = array[place.x][place.y]
			# Then set the original spot as the other piece
			array[place.x][place.y] = holder

func is_deadlocked():
	# Create a copy of the all_pieces array
	clone_array = copy_array(all_pieces)
	for i in width:
		for j in height:
			#switch and check right
			if switch_and_check(Vector2(i,j), Vector2(1, 0), clone_array):
				return false
			#switch and check up
			if switch_and_check(Vector2(i,j), Vector2(0, 1), clone_array):
				return false
	return true

func switch_and_check(place, direction, array):
	switch_pieces(place, direction, array)
	if find_matches(true, array):
		switch_pieces(place, direction, array)
		return true
	switch_pieces(place, direction, array)
	return false

func copy_array(array_to_copy):
	var new_array = make_2d_array()
	for i in width:
		for j in height:
			new_array[i][j] = array_to_copy[i][j]
	return new_array

func clear_and_store_board():
	var holder_array = []
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				holder_array.append(all_pieces[i][j])
				all_pieces[i][j] = null
	return holder_array

func shuffle_board():
	var holder_array = clear_and_store_board()
	for i in width:
		for j in height:
			if !restricted_fill(Vector2(i,j)) and all_pieces[i][j] == null:
				#choose a random number and store it
				var rand = floor(rand_range(0, holder_array.size()))
				var piece = holder_array[rand]
				var loops = 0
				while(match_at(i, j, piece.piece) && loops < 100):
					rand = floor(rand_range(0, holder_array.size()))
					loops += 1
					piece = holder_array[rand]
				# Instance that piece from the array
				piece.move(grid_to_pixel(i,j))
				all_pieces[i][j] = piece
				all_pieces[i][j].grid = Vector2(i,j)
				holder_array.remove(rand)
	if is_deadlocked():
		shuffle_board()
	state = move

func find_all_matches():
	var hint_holder = []
	clone_array = copy_array(all_pieces)
	for i in width:
		for j in height:
			if clone_array[i][j] != null and !restricted_move(Vector2(i,j)):
				if switch_and_check(Vector2(i,j), Vector2(1, 0), clone_array) and is_in_grid(Vector2(i + 1, j)) and !restricted_move(Vector2(i + 1, j)):
					#add the piece i,j to the hint_holder
					if match_c != "":
						if match_c == clone_array[i][j].piece:
							hint_holder.append(clone_array[i][j])
						else:
							hint_holder.append(clone_array[i + 1][j])
				if switch_and_check(Vector2(i,j), Vector2(0, 1), clone_array) and is_in_grid(Vector2(i, j + 1)) and !restricted_move(Vector2(i, j + 1)):
					#add the piece i,j to the hint_holder
					if match_c != "":
						if match_c == clone_array[i][j].piece:
							hint_holder.append(clone_array[i][j])
						else: 
							hint_holder.append(clone_array[i][j + 1])
	return hint_holder

func generate_hint():
	var hints = find_all_matches()
	if hints != null:
		if hints.size() > 0:
			destroy_hint()
			var rand = floor(rand_range(0, hints.size()))
			hint = hint_effect.instance()
			add_child(hint)
			hint.position = hints[rand].position
			hint.Setup(hints[rand].get_node("Sprite").texture)

func destroy_hint():
	if hint:
		hint.queue_free()
		hint = null

func make_booster_active(booster_type):
	if state == move:
		state = booster
		current_booster_type = booster_type
	elif state == booster:
		state = move
		current_booster_type = ""

func booster_input():
	if Input.is_action_just_pressed("ui_touch"):
		pass

func add_to_counter():
	"""
	if is_moves:
		emit_signal("update_counter", 5)
	else:
		emit_signal("update_counter", 10)
	"""
	state = move


func cam_effect():
	emit_signal("camera_effect")

func _on_destroy_timer_timeout():
	destroy_matched()

func declare_game_over():
	emit_signal("game_over")
	state = wait

func _on_GoalHolder_game_won():
	state = win

func _on_HintTimer_timeout():
	generate_hint()

#This should go in the game manager
func _on_bottom_ui_booster(booster_type):
	make_booster_active(booster_type)

func _on_Game_game_lost():
	state = wait

func _on_Game_game_won():
	state = wait


func _on_Game_set_dimensions(new_width, new_height):
	width = new_width
	height = new_height

func _on_RefillTimer_timeout():
	refill_columns()

func _on_CollapseTimer_timeout():
	collapse_columns()


func _on_DestroyTimer_timeout():
	destroy_matched()
