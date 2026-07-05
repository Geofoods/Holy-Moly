extends CanvasLayer

signal pause_toggled(is_paused: bool)

var is_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	var panel = $CenterContainer/PausePanel
	var label = $Label
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.call_deferred("set", "pivot_offset", panel.size / 2.0)
	label.modulate.a = 0.0
	label.scale = Vector2(0.9, 0.9)
	$DimBackground.modulate.a = 0.0
	_set_input_enabled(false)
	call_deferred("_position_hp_label")
	call_deferred("_sync_pause_heart")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
			get_tree().root.set_input_as_handled()

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

	var panel = $CenterContainer/PausePanel
	var label = $Label
	var dim_tween := create_tween()
	dim_tween.tween_property($DimBackground, "modulate:a", 1.0 if is_paused else 0.0, 0.2)

	if is_paused:
		_set_input_enabled(true)
		panel.scale = Vector2(0.9, 0.9)
		label.scale = Vector2(0.9, 0.9)
		_sync_pause_heart()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 0.0, 0.15)
		tween.tween_property(label, "modulate:a", 0.0, 0.15)
		tween.tween_property(label, "scale", Vector2(0.9, 0.9), 0.15)
		await tween.finished
		_set_input_enabled(false)

	pause_toggled.emit(is_paused)

func _set_input_enabled(enabled: bool) -> void:
	$DimBackground.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	$CenterContainer.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	$CenterContainer/PausePanel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

	var button_container = $CenterContainer/PausePanel/VBoxContainer/ButtonContainer
	button_container.get_node("ResumeButton").disabled = not enabled
	button_container.get_node("RestartButton").disabled = not enabled
	button_container.get_node("FieldGuideButton").disabled = not enabled
	button_container.get_node("MainMenuButton").disabled = not enabled
	button_container.get_node("CancelButton").disabled = not enabled

func _position_hp_label() -> void:
	var panel = $CenterContainer/PausePanel as Control
	var label = $Label as Control
	label.position = panel.global_position + Vector2(panel.size.x * 0.54, panel.size.y + 14.0)

func _sync_pause_heart() -> void:
	var source_heart := get_parent().get_node_or_null("CanvasLayer/heart/AnimatedSprite2D")
	var pause_heart := $CenterContainer/PausePanel/heart/AnimatedSprite2D
	if source_heart and pause_heart:
		pause_heart.animation = source_heart.animation
		pause_heart.frame = source_heart.frame
		pause_heart.frame_progress = source_heart.frame_progress
		pause_heart.play()

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	if SFX.has_method("play_ui"):
		SFX.play_ui("ui_click")
	Inventory.reset()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(Inventory.current_level_path)

func _on_field_guide_pressed() -> void:
	var info_popup = get_parent().get_node_or_null("InfoPopup")
	if info_popup:
		info_popup.open()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _on_cancel_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
