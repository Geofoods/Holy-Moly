extends CanvasLayer

signal pause_toggled(is_paused: bool)

var is_paused = false

func _ready():
	get_tree().paused = false

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
			get_tree().root.set_input_as_handled()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	$DimBackground.visible = is_paused
	$CenterContainer.visible = is_paused
	
	pause_toggled.emit(is_paused)

func _on_resume_pressed():
	toggle_pause()

func _on_exit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
