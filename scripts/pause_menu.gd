extends CanvasLayer

signal pause_toggled(is_paused: bool)

var is_paused := false
var _button_tweens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	var panel = $CenterContainer/PausePanel
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.call_deferred("set", "pivot_offset", panel.size / 2.0)
	$DimBackground.modulate.a = 0.0
	$DimBackground.gui_input.connect(_on_background_input)
	for button_path in [
		"CenterContainer/PausePanel/VBoxContainer/ButtonContainer/ResumeButton",
		"CenterContainer/PausePanel/VBoxContainer/ButtonContainer/RestartButton",
		"CenterContainer/PausePanel/VBoxContainer/ButtonContainer/FieldGuideButton",
		"CenterContainer/PausePanel/VBoxContainer/ButtonContainer/MapButton",
		"CenterContainer/PausePanel/VBoxContainer/ButtonContainer/MainMenuButton",
	]:
		var button := get_node(button_path) as Button
		button.pivot_offset = button.size / 2.0
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))
		button.pressed.connect(_on_button_pressed.bind(button))
	_set_input_enabled(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_PAUSE:
			# The map overlay pauses the tree as well. Toggling here too would
			# leave this menu's own flag out of step with the tree's.
			if MapOverlay.is_map_open():
				return
			toggle_pause()
			get_tree().root.set_input_as_handled()

func _on_button_hover(button: Button) -> void:
	if button.disabled:
		return
	SFX.play_ui("ui_hover", -18.0, 1.8)
	_animate_button(button, Vector2(1.04, 1.04), 0.12, Tween.TRANS_BACK)

func _on_button_unhover(button: Button) -> void:
	_animate_button(button, Vector2.ONE, 0.1, Tween.TRANS_SINE)

func _on_button_pressed(button: Button) -> void:
	SFX.play_ui("ui_click", -10.0, 1.15)
	_animate_button(button, Vector2(0.96, 0.96), 0.06, Tween.TRANS_QUAD)

func _animate_button(button: Button, target_scale: Vector2, duration: float, transition: Tween.TransitionType) -> void:
	button.pivot_offset = button.size / 2.0
	var button_id := button.get_instance_id()
	var old_tween: Tween = _button_tweens.get(button_id)
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var tween := create_tween()
	_button_tweens[button_id] = tween
	tween.tween_property(button, "scale", target_scale, duration).set_trans(transition).set_ease(Tween.EASE_OUT)

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

	var panel = $CenterContainer/PausePanel
	var dim_tween := create_tween()
	dim_tween.tween_property($DimBackground, "modulate:a", 1.0 if is_paused else 0.0, 0.2)

	if is_paused:
		_set_input_enabled(true)
		# Keyboard and gamepad players get focus on Resume the moment the menu
		# opens, so the menu is usable without a mouse.
		$CenterContainer/PausePanel/VBoxContainer/ButtonContainer/ResumeButton.call_deferred("grab_focus")
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
	# The layer itself starts hidden in some scenes (tutorial, map), so the
	# root has to follow the same state as its children or the menu never
	# appears - same contract InfoPopup keeps with its own visibility.
	visible = enabled
	$DimBackground.visible = enabled
	$CenterContainer.visible = enabled
	$DimBackground.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	$CenterContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterContainer/PausePanel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

	var button_container = $CenterContainer/PausePanel/VBoxContainer/ButtonContainer
	for button in button_container.get_children():
		if button is Button:
			button.disabled = not enabled
	button_container.get_node("ResumeButton").disabled = not enabled
	button_container.get_node("RestartButton").disabled = not enabled
	button_container.get_node("FieldGuideButton").disabled = not enabled
	button_container.get_node("MapButton").disabled = not enabled
	button_container.get_node("MainMenuButton").disabled = not enabled

func _on_background_input(event: InputEvent) -> void:
	if is_paused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_pause()

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	Inventory.player_health = Inventory.MAX_HEALTH
	_wipe_to(get_tree().current_scene.scene_file_path)

func _on_field_guide_pressed() -> void:
	var info_popup = get_parent().get_node_or_null("InfoPopup")
	if info_popup:
		info_popup.open()

## Hands the screen to the map overlay. This menu is already paused by the time
## the button can be pressed, so the map opens over it and leaves the pause
## alone; closing the map brings this menu straight back.
func _on_map_pressed() -> void:
	MapOverlay.open_map()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	_wipe_to("res://scenes/intro.tscn")

## Leaves and re-enters levels through the same circle wipe the rest of the game
## uses, so restarting or quitting never hard-cuts.
func _wipe_to(path: String) -> void:
	if path.is_empty():
		return
	var transition = preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(path)
