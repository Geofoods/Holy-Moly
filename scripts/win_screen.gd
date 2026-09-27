extends Control

var _button_tweens: Dictionary = {}

func _ready():
	LevelMusic.stop()
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)
	for btn in [$CenterContainer/VBoxContainer/ButtonContainer/MainMenuButton, $CenterContainer/VBoxContainer/ButtonContainer/CreditsButton, $CenterContainer/VBoxContainer/ButtonContainer/CancelButton]:
		_setup_button_hover(btn)
		btn.pressed.connect(_on_button_pressed.bind(btn))
	_spawn_confetti()
	animate_win()

func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	btn.mouse_exited.connect(_on_button_unhover.bind(btn))

func _on_button_hover(btn: Button) -> void:
	if btn.disabled:
		return
	SFX.play_ui("ui_hover", -18.0, 1.8)
	_animate_button(btn, Vector2(1.06, 1.06), 0.12, Tween.TRANS_BACK)

func _on_button_unhover(btn: Button) -> void:
	_animate_button(btn, Vector2.ONE, 0.1, Tween.TRANS_SINE)

func _on_button_pressed(btn: Button) -> void:
	_animate_button(btn, Vector2(0.96, 0.96), 0.06, Tween.TRANS_QUAD)

func _animate_button(btn: Button, target: Vector2, duration: float, transition: Tween.TransitionType) -> void:
	var button_id := btn.get_instance_id()
	var old_tween: Tween = _button_tweens.get(button_id)
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var tween := create_tween()
	_button_tweens[button_id] = tween
	tween.tween_property(btn, "scale", target, duration).set_trans(transition).set_ease(Tween.EASE_OUT)

func _spawn_confetti() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in 60:
		var particle := CPUParticles2D.new()
		particle.emitting = true
		particle.one_shot = true
		particle.amount = 1
		particle.lifetime = randf_range(1.5, 3.0)
		particle.explosiveness = 1.0
		particle.direction = Vector2(randf_range(-0.3, 0.3), -1)
		particle.spread = 30.0
		particle.initial_velocity_min = 150.0
		particle.initial_velocity_max = 400.0
		particle.gravity = Vector2(0, 300)
		particle.scale_amount_min = 3.0
		particle.scale_amount_max = 6.0
		var hue := randf_range(0.0, 1.0)
		particle.color = Color.from_hsv(hue, 0.8, 1.0, 1.0)
		var fade := Gradient.new()
		fade.set_color(0, Color.from_hsv(hue, 0.8, 1.0, 1.0))
		fade.set_color(1, Color.from_hsv(hue, 0.8, 1.0, 0.0))
		particle.color_ramp = fade
		particle.global_position = Vector2(randf_range(0, viewport_size.x), randf_range(-100, -20))
		particle.z_index = 100
		add_child(particle)
		get_tree().create_timer(particle.lifetime + 0.5).timeout.connect(particle.queue_free)

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
	var main_btn = $CenterContainer/VBoxContainer/ButtonContainer/MainMenuButton
	var credits_btn = $CenterContainer/VBoxContainer/ButtonContainer/CreditsButton
	var cancel_btn = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton
	main_btn.disabled = not enabled
	credits_btn.disabled = not enabled
	cancel_btn.disabled = not enabled
	if enabled:
		main_btn.pivot_offset = main_btn.size / 2.0
		credits_btn.pivot_offset = credits_btn.size / 2.0
		cancel_btn.pivot_offset = cancel_btn.size / 2.0

func _on_main_menu_pressed():
	SFX.play_ui("ui_click")
	Inventory.player_health = Inventory.MAX_HEALTH
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/level1.tscn")

func _on_credits_pressed():
	SFX.play_ui("ui_click")
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/credits.tscn")

func _on_cancel_pressed():
	SFX.play_ui("ui_click")
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")
