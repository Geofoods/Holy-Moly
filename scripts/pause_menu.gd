extends CanvasLayer

signal pause_toggled(is_paused: bool)

var is_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	var panel = $CenterContainer/PausePanel
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.call_deferred("set", "pivot_offset", panel.size / 2.0)
	$DimBackground.modulate.a = 0.0
	$DimBackground.gui_input.connect(_on_background_input)
	_set_input_enabled(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_PAUSE:
			toggle_pause()
			get_tree().root.set_input_as_handled()

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

	var panel = $CenterContainer/PausePanel
	var dim_tween := create_tween()
	dim_tween.tween_property($DimBackground, "modulate:a", 1.0 if is_paused else 0.0, 0.2)

	if is_paused:
		_set_input_enabled(true)
		panel.scale = Vector2(0.9, 0.9)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 0.0, 0.15)
		await tween.finished
		_set_input_enabled(false)

	pause_toggled.emit(is_paused)

func _set_input_enabled(enabled: bool) -> void:
	$DimBackground.visible = enabled
	$CenterContainer.visible = enabled
	$DimBackground.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	$CenterContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterContainer/PausePanel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

	var button_container = $CenterContainer/PausePanel/VBoxContainer/ButtonContainer
	button_container.get_node("ResumeButton").disabled = not enabled
	button_container.get_node("FieldGuideButton").disabled = not enabled
	button_container.get_node("MainMenuButton").disabled = not enabled

func _on_background_input(event: InputEvent) -> void:
	if is_paused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_pause()

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_field_guide_pressed() -> void:
	var info_popup = get_parent().get_node_or_null("InfoPopup")
	if info_popup:
		info_popup.open()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
