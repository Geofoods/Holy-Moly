extends Control

const MOLE_SIZE := Vector2(180.0, 240.0)
const HOP_COUNT := 4
const HOP_HEIGHT := 90.0
const HOP_DURATION := 1.7
const GROUND_RATIO := 0.72
const TIPS := [
	"> Press shift to dig and dash.",
	"> Press ESC to check your HP.",
	"> Do NOT fall for the corruption.",
	"> Moles can paralyse worms with their spit.",
	"> Made for the Pixel Forge game jam.",
]

var tip_tween: Tween
var tip_rng := RandomNumberGenerator.new()

func _ready():
	tip_rng.randomize()
	var vp_size: Vector2 = get_viewport_rect().size
	size = vp_size
	$Background.size = vp_size
	$CenterContainer.size = vp_size
	_set_random_tip()

	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)

	var play_btn = $CenterContainer/VBoxContainer/ButtonContainer/PlayButton
	var cancel_btn = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton
	play_btn.mouse_entered.connect(_on_button_hover.bind(play_btn))
	play_btn.mouse_exited.connect(_on_button_unhover.bind(play_btn))
	cancel_btn.mouse_entered.connect(_on_button_hover.bind(cancel_btn))
	cancel_btn.mouse_exited.connect(_on_button_unhover.bind(cancel_btn))

	animate_intro()

func animate_intro():
	await animate_mole_hop()
	await get_tree().create_timer(0.15).timeout
	animate_menu_reveal()

func animate_mole_hop() -> void:
	var mole = $MoleAnimation
	var viewport_size: Vector2 = get_viewport_rect().size

	mole.size = MOLE_SIZE
	mole.pivot_offset = Vector2(MOLE_SIZE.x / 2.0, MOLE_SIZE.y)

	var start_x := -MOLE_SIZE.x
	var end_x := viewport_size.x + MOLE_SIZE.x
	var ground_y := viewport_size.y * GROUND_RATIO - MOLE_SIZE.y

	mole.position = Vector2(start_x, ground_y)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float): _update_mole_hop(mole, t, start_x, end_x, ground_y),
		0.0, 1.0, HOP_DURATION
	)
	await tween.finished

func _update_mole_hop(mole: Control, t: float, start_x: float, end_x: float, ground_y: float) -> void:
	var x: float = lerp(start_x, end_x, t)

	var hop_phase := fmod(t * HOP_COUNT, 1.0)
	var arc := sin(hop_phase * PI)
	var y := ground_y - HOP_HEIGHT * arc

	mole.position = Vector2(x, y)
	mole.scale = Vector2(lerp(1.15, 0.9, arc), lerp(0.85, 1.15, arc))
	mole.rotation_degrees = sin(t * HOP_COUNT * PI * 2.0) * 6.0

func animate_menu_reveal() -> void:
	var vbox = $CenterContainer/VBoxContainer
	_set_buttons_enabled(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_start_tip_wobble)

func _set_buttons_enabled(enabled: bool) -> void:
	var play_btn = $CenterContainer/VBoxContainer/ButtonContainer/PlayButton
	var cancel_btn = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton
	play_btn.disabled = not enabled
	cancel_btn.disabled = not enabled
	if enabled:
		play_btn.pivot_offset = play_btn.size / 2.0
		cancel_btn.pivot_offset = cancel_btn.size / 2.0

func _on_button_hover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_button_unhover(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_random_tip() -> void:
	$CenterContainer/VBoxContainer/TipWrapper/SubtitleLabel.text = TIPS[tip_rng.randi_range(0, TIPS.size() - 1)]

func _start_tip_wobble() -> void:
	var tip = $CenterContainer/VBoxContainer/TipWrapper/SubtitleLabel
	if tip_tween:
		tip_tween.kill()
	tip_tween = create_tween().set_loops()
	tip_tween.tween_property(tip, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tip_tween.tween_property(tip, "position:y", 5.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_cancel_pressed():
	get_tree().quit()
