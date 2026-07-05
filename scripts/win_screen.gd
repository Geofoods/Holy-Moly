extends Control

func _ready():
	var viewport_size: Vector2 = get_viewport_rect().size
	$Sprite2D.position = viewport_size / 2.0
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)
	animate_win()

func animate_win() -> void:
	await get_tree().create_timer(0.2).timeout
	animate_menu_reveal()

func animate_menu_reveal() -> void:
	var vbox = $CenterContainer/VBoxContainer
	_set_buttons_enabled(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_buttons_enabled(enabled: bool) -> void:
	$CenterContainer/VBoxContainer/ButtonContainer/PlayAgainButton.disabled = not enabled
	$CenterContainer/VBoxContainer/ButtonContainer/CancelButton.disabled = not enabled

func _on_play_again_pressed():
	SFX.play_ui("ui_click")
	Inventory.reset()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(Inventory.current_level_path)

func _on_cancel_pressed():
	SFX.play_ui("ui_click")
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")
