extends Control

const MOLE_SIZE := Vector2(180.0, 240.0)
const GROUND_RATIO := 0.72
const FALL_START_RATIO := 0.22
const FALL_X_RATIO := 0.78

var _game_over_music: AudioStreamPlayer = null

func _ready():
	LevelMusic.stop()
	_start_game_over_music()
	var viewport_size: Vector2 = get_viewport_rect().size
	$AnimatedSprite2D.position = viewport_size / 2.0
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)
	for btn in [$CenterContainer/VBoxContainer/ButtonContainer/PlayButton, $CenterContainer/VBoxContainer/ButtonContainer/CancelButton]:
		_setup_button_hover(btn)

	animate_game_over()

func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		if btn.disabled:
			return
		SFX.play_ui("ui_hover", -18.0, 1.8)
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)

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

	var break_sound := AudioStreamPlayer2D.new()
	break_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	break_sound.stream = load("res://sounds/break_corrupted_1.ogg")
	break_sound.volume_db = -2.0
	break_sound.pitch_scale = randf_range(0.8, 1.0)
	add_child(break_sound)
	break_sound.play()
	break_sound.finished.connect(break_sound.queue_free)

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
	for btn in [$CenterContainer/VBoxContainer/ButtonContainer/PlayButton, $CenterContainer/VBoxContainer/ButtonContainer/CancelButton]:
		btn.disabled = not enabled
		if enabled:
			btn.pivot_offset = btn.size / 2.0

func _start_game_over_music() -> void:
	_game_over_music = AudioStreamPlayer.new()
	_game_over_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_music.stream = preload("res://soundreality-crystal-cave-136472.mp3")
	_game_over_music.volume_db = -14.0
	add_child(_game_over_music)
	_game_over_music.finished.connect(_game_over_music.play)
	_game_over_music.play()

func _fade_out_game_over_music() -> void:
	if _game_over_music and is_instance_valid(_game_over_music):
		var tween := create_tween()
		tween.tween_property(_game_over_music, "volume_db", -40.0, 0.8)
		tween.tween_callback(_game_over_music.queue_free)
		_game_over_music = null

func _on_play_again_pressed():
	SFX.play_ui("ui_click")
	_fade_out_game_over_music()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/level1.tscn")

func _on_cancel_pressed():
	SFX.play_ui("ui_click")
	_fade_out_game_over_music()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")
