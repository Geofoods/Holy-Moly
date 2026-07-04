extends Control

const MOLE_SIZE := Vector2(180.0, 240.0)
const GROUND_RATIO := 0.72
const FALL_START_RATIO := 0.22
const FALL_X_RATIO := 0.78

func _ready():
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)

	animate_game_over()

func animate_game_over() -> void:
	await animate_mole_death()
	await get_tree().create_timer(0.2).timeout
	animate_menu_reveal()

func animate_mole_death() -> void:
	var mole = $MoleAnimation
	var viewport_size: Vector2 = get_viewport_rect().size

	mole.size = MOLE_SIZE
	mole.pivot_offset = Vector2(MOLE_SIZE.x / 2.0, MOLE_SIZE.y)

	var fall_x := viewport_size.x * FALL_X_RATIO - MOLE_SIZE.x / 2.0
	var start_y := viewport_size.y * FALL_START_RATIO - MOLE_SIZE.y
	var ground_y := viewport_size.y * GROUND_RATIO - MOLE_SIZE.y

	mole.position = Vector2(fall_x, start_y)
	mole.rotation_degrees = 0.0
	mole.modulate = Color(1, 1, 1, 1)
	mole.scale = Vector2(1.0, 1.0)

	var fall_tween := create_tween()
	fall_tween.set_parallel(true)
	fall_tween.tween_property(mole, "position:y", ground_y, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(mole, "rotation_degrees", 280.0, 0.55).set_trans(Tween.TRANS_LINEAR)
	await fall_tween.finished

	$DeathFlash.modulate.a = 0.55
	var flash_tween := create_tween()
	flash_tween.tween_property($DeathFlash, "modulate:a", 0.0, 0.35)

	var settle_tween := create_tween()
	settle_tween.set_parallel(true)
	settle_tween.tween_property(mole, "scale", Vector2(1.3, 0.55), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(mole, "modulate", Color(0.5, 0.15, 0.15, 1.0), 0.6)
	await settle_tween.finished

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
	Inventory.reset()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(Inventory.current_level_path)

func _on_cancel_pressed():
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")
