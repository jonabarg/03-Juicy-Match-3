extends Control


func show_goals():
	var goal = ""
	for g in Global.goal:
		var temp = g["piece"] + ": " + str(g["count"]) + "/" + str(g["max"]) + "\n"
		goal += temp
	$Goals.text = goal
		
	
