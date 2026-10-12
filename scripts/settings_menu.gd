extends CanvasLayer

## The settings screen. Reached from the title screen and from the pause menu, so
## it lives on its own always-running layer above both rather than inside either
## scene. Opening pauses the tree and shows the panel; closing hands the pause
## back the way it was found, so opening it from the pause menu leaves that menu
## standing when it is dismissed.
##
## Its one control for now is the on-screen touch controls toggle: auto-detection
## still picks the starting state (see mobile_controls.gd), and this switch
## overrides it for the session - a touchscreen desktop can switch them on, a
## phone can switch them off.

var is_open := false
## The tree's paused flag before this screen raised it. Opening from the pause
## menu happens on an already-paused tree, and that menu expects to still own the
## pause when the settings screen is dismissed.
var _was_paused_before := false

@onready var _dim: ColorRect = $DimBackground
@onready var _panel: Control = $CenterContainer/Panel
@onready var _mobile_check: CheckBox = $CenterContainer/Panel/Margin/VBox/MobileControlsCheck

func _ready() -> void:
	# Keep processing while the tree is paused: this screen is what pauses it
	# when opened from a level, and its own Buttons still have to work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	_panel.call_deferred("set", "pivot_offset", _panel.size / 2.0)
	_dim.gui_input.connect(_on_dim_input)

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if is_open:
		return
	is_open = true
	_was_paused_before = get_tree().paused
	get_tree().paused = true
	# Start from the state the controls are actually in, silently, so opening the
	# screen does not fire the toggled handler and its click sound.
	_mobile_check.set_pressed_no_signal(MobileControls.enabled)
	visible = true
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mobile_check.call_deferred("grab_focus")

func close() -> void:
	if not is_open:
		return
	is_open = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.15)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.15)
	await tween.finished
	visible = false
	# Only lift the pause this screen raised. Opened from the pause menu, the
	# pause outlives this screen and unpausing here would leave that menu showing
	# over a running level.
	get_tree().paused = _was_paused_before

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func _on_dim_input(event: InputEvent) -> void:
	if is_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_close_pressed() -> void:
	SFX.play_ui("ui_click", -10.0, 1.15)
	close()

## Turns the on-screen touch controls on or off by hand. Auto-detection still
## picks the starting state (see mobile_controls.gd); this overrides it for the
## session - a touchscreen desktop can switch them on, a phone can switch them
## off.
func _on_mobile_controls_toggled(pressed: bool) -> void:
	SFX.play_ui("ui_click", -6.0, 1.2)
	MobileControls.set_enabled(pressed)
