extends Node2D

enum {play, win, lose, pause}

var state = play
# Board Variables
export (int) var width
export (int) var height

# Level Variables
export (int) var level
export (bool) var is_moves
export (int) var max_counter
var current_counter

# Score Variables
var current_high_score
var current_score
export (int) var max_score
export (int) var points_per_piece

# Signals
signal set_dimensions

# Called when the node enters the scene tree for the first time.
func _ready():
	setup()
	is_moves = true
	Global.update_level(0)

func setup():
	emit_signal("set_dimensions", width, height)

