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
	ScoreManager.finalize()
	_add_score_display(vbox)

	animate_game_over()

func _add_score_display(vbox: VBoxContainer) -> void:
	var font := load("res://Baby Doll.otf") as Font
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)

	var final_label := Label.new()
	final_label.text = "FINAL SCORE:  %d" % ScoreManager.current_score
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.add_theme_font_override("font", font)
	final_label.add_theme_font_size_override("font_size", 46)
	final_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1))
	final_label.add_theme_constant_override("outline_size", 6)
	final_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	box.add_child(final_label)

	var best_label := Label.new()
	best_label.text = "BEST:  %d" % ScoreManager.high_score
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_override("font", font)
	best_label.add_theme_font_size_override("font_size", 28)
	best_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.75, 1))
	best_label.add_theme_constant_override("outline_size", 4)
	best_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	box.add_child(best_label)

	vbox.add_child(box)
	vbox.move_child(box, 1)

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
	$CenterContainer/VBoxContainer/ButtonContainer/PlayAgainButton.disabled = not enabled
	$CenterContainer/VBoxContainer/ButtonContainer/CancelButton.disabled = not enabled

func _start_game_over_music() -> void:
	_game_over_music = AudioStreamPlayer.new()
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
	Inventory.reset()
	ScoreManager.start_new_run()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(Inventory.current_level_path)

func _on_cancel_pressed():
	SFX.play_ui("ui_click")
	_fade_out_game_over_music()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")
