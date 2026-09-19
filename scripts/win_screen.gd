extends Control

func _ready():
	LevelMusic.stop()
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.scale = Vector2(0.85, 0.85)
	vbox.call_deferred("set", "pivot_offset", vbox.size / 2.0)
	_set_buttons_enabled(false)
	for btn in [$CenterContainer/VBoxContainer/ButtonContainer/MainMenuButton, $CenterContainer/VBoxContainer/ButtonContainer/CancelButton]:
		_setup_button_hover(btn)
	_spawn_confetti()
	animate_win()

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
	var cancel_btn = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton
	main_btn.disabled = not enabled
	cancel_btn.disabled = not enabled
	if enabled:
		main_btn.pivot_offset = main_btn.size / 2.0
		cancel_btn.pivot_offset = cancel_btn.size / 2.0

func _on_main_menu_pressed():
	SFX.play_ui("ui_click")
	Inventory.player_health = Inventory.MAX_HEALTH
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/level1.tscn")

func _on_cancel_pressed():
	SFX.play_ui("ui_click")
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")
