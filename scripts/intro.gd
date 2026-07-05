extends Control

const MOLE_SIZE := Vector2(180.0, 240.0)
const HOP_COUNT := 4
const HOP_HEIGHT := 90.0
const HOP_DURATION := 1.7
const GROUND_RATIO := 0.72

var _level_keys: Array = []
var _last_hop_index := -1
var _intro_music: AudioStreamPlayer = null

func _ready():
	LevelMusic.stop()
	var vp_size: Vector2 = get_viewport_rect().size
	size = vp_size
	$Background.size = vp_size
	$CenterContainer.size = vp_size
	
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)

	$MoleShadow.hide()

	var play_btn = $CenterContainer/VBoxContainer/ButtonContainer/PlayButton
	var tutorial_btn = $CenterContainer/VBoxContainer/ButtonContainer/TutorialButton
	var level_picker = $CenterContainer/VBoxContainer/ButtonContainer/LevelPickerOption as OptionButton
	var cancel_btn = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton
	play_btn.mouse_entered.connect(_on_button_hover.bind(play_btn))
	play_btn.mouse_exited.connect(_on_button_unhover.bind(play_btn))
	tutorial_btn.mouse_entered.connect(_on_button_hover.bind(tutorial_btn))
	tutorial_btn.mouse_exited.connect(_on_button_unhover.bind(tutorial_btn))
	level_picker.mouse_entered.connect(_on_button_hover.bind(level_picker))
	level_picker.mouse_exited.connect(_on_button_unhover.bind(level_picker))
	cancel_btn.mouse_entered.connect(_on_button_hover.bind(cancel_btn))
	cancel_btn.mouse_exited.connect(_on_button_unhover.bind(cancel_btn))
	
	_setup_level_picker(level_picker)

	animate_intro()

func animate_intro():
	_intro_music = AudioStreamPlayer.new()
	_intro_music.stream = preload("res://ivan_luzan-epic-hybrid-logo-157092.mp3")
	_intro_music.volume_db = -4.0
	add_child(_intro_music)
	_intro_music.play()
	await animate_mole_hop()
	await get_tree().create_timer(0.15).timeout
	_fade_out_intro_music()
	animate_menu_reveal()

func _fade_out_intro_music() -> void:
	if not _intro_music:
		return
	var tween := create_tween()
	tween.tween_property(_intro_music, "volume_db", -40.0, 0.5)
	tween.tween_callback(_intro_music.queue_free)
	_start_menu_music()

func _start_menu_music() -> void:
	var music := AudioStreamPlayer.new()
	music.stream = preload("res://pink_sound-neon-symphony-phonk-house-background-music-for-video-21-second-533504.mp3")
	music.volume_db = -14.0
	music.pitch_scale = 0.8
	music.name = "MenuMusic"
	add_child(music)
	music.finished.connect(music.play)
	music.play()

func animate_mole_hop() -> void:
	var mole = $MoleAnimation
	var shadow = $MoleShadow
	var viewport_size: Vector2 = get_viewport_rect().size

	mole.size = MOLE_SIZE
	mole.pivot_offset = Vector2(MOLE_SIZE.x / 2.0, MOLE_SIZE.y)
	shadow.show()

	var start_x := -MOLE_SIZE.x - 100.0
	var end_x := viewport_size.x + MOLE_SIZE.x + 100.0
	var ground_y := viewport_size.y * GROUND_RATIO - MOLE_SIZE.y

	mole.position = Vector2(start_x, ground_y)
	shadow.position = Vector2(start_x + MOLE_SIZE.x / 2.0, ground_y + MOLE_SIZE.y)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float): _update_mole_hop(mole, shadow, t, start_x, end_x, ground_y),
		0.0, 1.0, HOP_DURATION
	)
	await tween.finished

	shadow.hide()

func _update_mole_hop(mole: Control, shadow: ColorRect, t: float, start_x: float, end_x: float, ground_y: float) -> void:
	var x: float = lerp(start_x, end_x, t)

	var hop_index := int(t * HOP_COUNT)
	if hop_index != _last_hop_index and hop_index < HOP_COUNT:
		_last_hop_index = hop_index
		SFX.play_ui("jump")

	var hop_phase := fmod(t * HOP_COUNT, 1.0)
	var arc := sin(hop_phase * PI)
	var y := ground_y - HOP_HEIGHT * arc

	mole.position = Vector2(x, y)
	mole.scale = Vector2(lerp(1.15, 0.9, arc), lerp(0.85, 1.15, arc))
	mole.rotation_degrees = sin(t * HOP_COUNT * PI * 2.0) * 6.0

	var shadow_squash: float = lerp(1.5, 0.6, arc)
	shadow.position = Vector2(x + MOLE_SIZE.x / 2.0, ground_y + MOLE_SIZE.y + 4.0)
	shadow.scale = Vector2(shadow_squash, 1.0 / shadow_squash)
	shadow.modulate.a = lerp(0.0, 0.4, 1.0 - arc)

func animate_menu_reveal() -> void:
	var vbox = $CenterContainer/VBoxContainer
	_set_buttons_enabled(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_buttons_enabled(enabled: bool) -> void:
	var play_btn = $CenterContainer/VBoxContainer/ButtonContainer/PlayButton
	var tutorial_btn = $CenterContainer/VBoxContainer/ButtonContainer/TutorialButton
	var level_picker = $CenterContainer/VBoxContainer/ButtonContainer/LevelPickerOption as OptionButton
	var cancel_btn = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton
	play_btn.disabled = not enabled
	tutorial_btn.disabled = not enabled
	level_picker.disabled = not enabled
	cancel_btn.disabled = not enabled
	if enabled:
		play_btn.pivot_offset = play_btn.size / 2.0
		tutorial_btn.pivot_offset = tutorial_btn.size / 2.0
		level_picker.pivot_offset = level_picker.size / 2.0
		cancel_btn.pivot_offset = cancel_btn.size / 2.0

func _on_button_hover(button: Button) -> void:
	if button.disabled:
		return
	SFX.play_ui("ui_hover", -18.0, 1.8)
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "modulate:a", 1.1, 0.12)

func _on_button_unhover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "modulate:a", 1.0, 0.1)

func _fade_out_menu_music() -> void:
	var music = get_node_or_null("MenuMusic")
	if music:
		var tween := create_tween()
		tween.tween_property(music, "volume_db", -40.0, 0.8)
		tween.tween_callback(music.queue_free)

func _on_play_pressed() -> void:
	SFX.play_ui("ui_click", -6.0, 1.2)
	_fade_out_menu_music()
	var play_btn = $CenterContainer/VBoxContainer/ButtonContainer/PlayButton
	play_btn.disabled = true
	Inventory.reset()
	var picker = $CenterContainer/VBoxContainer/ButtonContainer/LevelPickerOption as OptionButton
	var selected: int = picker.selected
	var target := "res://scenes/main.tscn"
	if selected > 0 and selected - 1 < _level_keys.size():
		target = _level_keys[selected - 1]
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(target)

func _on_tutorial_pressed() -> void:
	SFX.play_ui("ui_click", -6.0, 1.2)
	_fade_out_menu_music()
	var tutorial_btn = $CenterContainer/VBoxContainer/ButtonContainer/TutorialButton
	tutorial_btn.disabled = true
	Inventory.reset()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/tutorial.tscn")

func _setup_level_picker(picker: OptionButton) -> void:
	picker.clear()
	picker.add_item("LEVELS")
	picker.set_item_disabled(0, true)

	_level_keys = LevelData.LEVELS.keys()
	_level_keys.sort_custom(func(a, b): return LevelData.LEVELS[a]["number"] < LevelData.LEVELS[b]["number"])

	for key in _level_keys:
		var info: Dictionary = LevelData.LEVELS[key]
		picker.add_item("Level %d - %s" % [info["number"], info["name"]])

	picker.item_selected.connect(_on_level_picked)

	var arrow_size := 24
	var img := Image.create(arrow_size, arrow_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var black := Color(0.05, 0.05, 0.05, 1.0)
	for y in arrow_size:
		var progress := float(y) / float(arrow_size - 1)
		var half_w := int((1.0 - progress) * float(arrow_size) * 0.5)
		var cx: int = arrow_size / 2
		for x in range(cx - half_w, cx + half_w + 1):
			if x >= 0 and x < arrow_size:
				img.set_pixel(x, y, black)
	var arrow_tex := ImageTexture.create_from_image(img)
	picker.add_theme_icon_override("arrow", arrow_tex)
	picker.add_theme_constant_override("arrow_margin", 12)

func _on_level_picked(_index: int) -> void:
	SFX.play_ui("ui_click", -6.0, 1.2)

func _on_cancel_pressed():
	SFX.play_ui("ui_click", -6.0, 1.2)
	_fade_out_menu_music()
	get_tree().quit()
