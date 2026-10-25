extends CanvasLayer

## The settings screen. Reached from the title screen and from the pause menu, so
## it lives on its own always-running layer above both rather than inside either
## scene. Opening pauses the tree and shows the panel; closing hands the pause
## back the way it was found, so opening it from the pause menu leaves that menu
## standing when it is dismissed.
##
## It carries the on-screen touch controls toggle and a pair of volume sliders.
## Auto-detection picks the controls' starting state on a fresh save (see
## mobile_controls.gd); once the switch is used the choice is saved through
## Progress, so it survives a restart. The sliders drive the SFX and Music buses
## and the levels they land on are saved through Progress too.

## Buses the volume sliders drive. Created at startup by _ensure_buses().
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"

## Slider floor treated as silence. A slider all the way down mutes the bus
## outright rather than asking for -inf dB (see _apply_bus_volume).
const VOLUME_MUTED := 0.0001

var is_open := false
## The tree's paused flag before this screen raised it. Opening from the pause
## menu happens on an already-paused tree, and that menu expects to still own the
## pause when the settings screen is dismissed.
var _was_paused_before := false

@onready var _dim: ColorRect = $DimBackground
@onready var _panel: Control = $CenterContainer/Panel
@onready var _mobile_check: CheckBox = $CenterContainer/Panel/Margin/VBox/MobileControlsCheck
@onready var _sfx_slider: HSlider = $CenterContainer/Panel/Margin/VBox/SoundEffectsRow/SoundEffectsSlider
@onready var _music_slider: HSlider = $CenterContainer/Panel/Margin/VBox/MusicRow/MusicSlider

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
	# Prime the sliders before connecting, so setting them does not fire the
	# change handlers, then apply the mix once at startup so it is right before
	# this screen is ever opened. Progress has not read the save yet (see below),
	# so these are the defaults until _on_audio_settings_loaded corrects them.
	_sfx_slider.value = Progress.sfx_volume
	_music_slider.value = Progress.music_volume
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	_ensure_buses()
	_apply_volumes()
	# Progress owns the saved levels and reads them in its own _ready, which runs
	# after this one (autoload order), so adopt them once they have arrived.
	Progress.audio_settings_loaded.connect(_on_audio_settings_loaded)

## Adopts the levels Progress read from disk. Needed because that autoload's
## _ready runs after this one, so the sliders were primed from the defaults.
func _on_audio_settings_loaded() -> void:
	_sfx_slider.set_value_no_signal(Progress.sfx_volume)
	_music_slider.set_value_no_signal(Progress.music_volume)
	_apply_volumes()

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

## Turns the on-screen touch controls on or off by hand and remembers the
## choice. Until this is used once (or the Level Forge switch is), auto-detection
## picks the starting state on a mobile device; after it, the saved preference
## wins on every launch - a touchscreen desktop can switch them on, a phone can
## switch them off.
func _on_mobile_controls_toggled(pressed: bool) -> void:
	SFX.play_ui("ui_click", -6.0, 1.2)
	MobileControls.set_enabled(pressed)
	Progress.set_mobile_controls_override(pressed)

## Adds the SFX and Music buses if the layout does not already carry them, both
## routed to Master. Created here at startup rather than in default_bus_layout.tres
## so they exist before any player is assigned to them - every sound in the game
## names one of the two.
func _ensure_buses() -> void:
	for bus_name in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")

## Pushes the stored slider levels onto their buses, so the mix is applied the
## moment the game starts rather than only once a slider is touched.
func _apply_volumes() -> void:
	_apply_bus_volume(SFX_BUS, Progress.sfx_volume)
	_apply_bus_volume(MUSIC_BUS, Progress.music_volume)

## A slider at zero mutes the bus rather than asking for -inf dB; anything above
## it maps through the usual logarithm, so the travel feels even across the
## range instead of doing all of its work near the top.
func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= VOLUME_MUTED:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _on_sfx_volume_changed(value: float) -> void:
	Progress.set_sfx_volume(value)
	_apply_bus_volume(SFX_BUS, value)

func _on_music_volume_changed(value: float) -> void:
	Progress.set_music_volume(value)
	_apply_bus_volume(MUSIC_BUS, value)

## Blips once the sound-effects slider is let go, so the new level can be heard
## without leaving the screen. On release rather than on every step of the drag,
## which would machine-gun the click all the way across.
func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SFX.play_ui("ui_click", -6.0, 1.2)
