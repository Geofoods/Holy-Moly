extends CanvasLayer

func _on_exit_game_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
