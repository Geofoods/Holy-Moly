extends Control

func _ready():
	animate_intro()

func animate_intro():
	var mole = $MoleAnimation
	var vbox = $CenterContainer/VBoxContainer
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(mole, "offset_left", 1400.0, 2.0)
	tween.tween_property(mole, "offset_right", 1500.0, 2.0)
	
	await get_tree().create_timer(0.5).timeout
	var ui_tween = create_tween()
	ui_tween.set_ease(Tween.EASE_OUT)
	ui_tween.set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(vbox, "modulate:a", 1.0, 1.5)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_exit_pressed():
	get_tree().quit()
