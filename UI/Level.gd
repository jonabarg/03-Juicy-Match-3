extends Control

func show_level(level, instructions):
	get_tree().paused = true
	show()
	$Level.text = level
	$Instructions.text = instructions
	$Timer.start()

func _on_Timer_timeout():
	get_tree().paused = false
	hide()
