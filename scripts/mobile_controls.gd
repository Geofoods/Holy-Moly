extends CanvasLayer

## On-screen touch controls, shown only when the game is running on a mobile
## device (phone or tablet). The left thumb gets a virtual joystick that drives
## the ui_* movement actions with analog strength and jumps when it is pushed
## up; the right thumb gets interact (moles, chests, doors, ...) and a dig dash
## button that doubles as
## the ground pound while airborne, exactly like Shift does on desktop.
##
## Touches are turned into input the rest of the game already understands:
## buttons and the joystick drive the InputMap actions through Input.action_*
## (for everything polling Input.*) and through synthetic InputEventAction
## events (for everything reading events). Touches also arrive as emulated
## mouse clicks, so clicks landing on a control are swallowed here and skipped
## in the mole's item handling - tapping a control must not throw a bomb.
##
## On mobile the mouse is kept out of the "dig_slash" action (see
## _ensure_actions) and world taps are translated into dig_slash presses here
## instead, so a tap on a control can never swing the shovel.

const CIRCLE_TEX := preload("res://Default/button_circle.png")
const BURST_ICON := preload("res://Defaulticons/icon_burst.png")

## Dialogue boxes park over the bottom of the screen, right on top of the
## buttons, so the overlay steps aside while one is open - otherwise a tap on
## the dialogue's Next button lands on a control and never reaches the button.
## The script is loaded lazily on purpose: dialogue_box.gd names the SFX
## autoload, and autoload names aren't registered yet while the autoloads
## themselves are compiling, so an eager preload here trips over its own
## chicken-and-egg. A runtime load() has no such problem.
var _dialogue_script: Script = null

const STICK_SIZE := 230.0
const STICK_KNOB_SIZE := 104.0
const STICK_RADIUS := 92.0
const STICK_DEADZONE := 0.18
## How far up the stick must point before it counts as a jump (straight up is
## 1.0, a 45-degree up-forward push about 0.7).
const JUMP_TRIGGER := 0.5
const BUTTON_SIZE := 132.0
const SMALL_BUTTON_SIZE := 112.0
const SCREEN_MARGIN := 40.0
const BUTTON_GAP := 24.0

const STICK_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

## Scenes without gameplay - the title screen and the end screens - where the
## on-screen controls would only sit on top of the UI. Turning the controls on
## from the main menu must not draw them over that menu; they appear once a
## level is entered. Set in code so an editor re-save of a scene cannot
## re-enable them (the same approach mole.gd takes with PEACEFUL_SCENES).
const HIDDEN_SCENES := [
	"res://scenes/intro.tscn",
	"res://scenes/game_over.tscn",
	"res://scenes/win_screen.tscn",
	"res://scenes/credits.tscn",
]

## Emitted whenever the controls are switched on or off, so HUD elements that
## move out of the controls' way (see heart_hud.gd) can follow.
signal enabled_changed(is_on: bool)

var enabled := false

## Scene the overlay's visibility is currently derived from.
var _scene_path := ""
## Whether a dialogue box is open (see _refresh_visibility).
var _dialogue_open := false

var _stick_base: TextureRect = null
var _stick_knob: TextureRect = null
var _buttons: Dictionary = {}

## Touch index -> what that finger is holding: a button action, &"stick" or
## &"world" (a tap on the game world itself).
var _touches: Dictionary = {}
var _stick_touch := -1
var _world_touch := -1
var _stick_vector := Vector2.ZERO
## Whether the stick is currently holding ui_accept (the jump) down.
var _jump_held := false
var _axis_strength: Dictionary = {&"ui_left": 0.0, &"ui_right": 0.0, &"ui_up": 0.0, &"ui_down": 0.0}

func _ready() -> void:
	layer = 100
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_scene_path = _current_scene_path()
	set_enabled(is_mobile_device())

## The overlay belongs in gameplay, not on the menus, so its visibility follows
## whichever scene is current. Tracked here rather than pushed from each scene:
## every way into and out of a level goes through a scene change, and the
## transition's change_scene_to_* updates the current scene for us.
func _physics_process(_delta: float) -> void:
	var path := _current_scene_path()
	var talking := _dialogue_is_open()
	if path != _scene_path or talking != _dialogue_open:
		_scene_path = path
		_dialogue_open = talking
		_refresh_visibility()

func _current_scene_path() -> String:
	var cs := get_tree().current_scene
	return cs.scene_file_path if cs != null else ""

## True on phones and tablets. Native mobile exports report one of the mobile
## features; a web build cannot see the OS, so a touchscreen (without a desktop
## fallback being required) is the giveaway for a phone/tablet browser.
func is_mobile_device() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		return DisplayServer.is_touchscreen_available()
	return false

func set_enabled(on: bool) -> void:
	var changed := enabled != on
	enabled = on
	if on:
		_ensure_actions()
	_refresh_visibility()
	if changed:
		enabled_changed.emit(on)

func _dialogue_is_open() -> bool:
	if _dialogue_script == null:
		_dialogue_script = load("res://scripts/dialogue_box.gd")
	if _dialogue_script == null:
		return false
	# Boxes are parented to the tree root and live until shortly after they
	# close (dialogue_box.gd counts the fade-out on purpose), so any box under
	# root means the player is still reading - the same answer is_open() gives.
	for child in get_tree().root.get_children():
		if child.get_script() == _dialogue_script:
			return true
	return false

func _refresh_visibility() -> void:
	visible = enabled and not HIDDEN_SCENES.has(_scene_path) and not _dialogue_open
	if not visible:
		_release_everything()

## Keeps left clicks out of "dig_slash" on touch devices: every tap would
## otherwise press it too. mole.gd only binds the mouse to dig_slash when the
## action does not exist yet, so creating it here (with no bindings) is enough.
## World taps are sent as dig_slash presses from _touch_begin instead.
func _ensure_actions() -> void:
	if not InputMap.has_action(&"dig_slash"):
		InputMap.add_action(&"dig_slash")

func _build_ui() -> void:
	_stick_base = _make_circle(STICK_SIZE, 0.4)
	add_child(_stick_base)
	_stick_knob = _make_circle(STICK_KNOB_SIZE, 0.85)
	add_child(_stick_knob)
	_buttons[&"dig_dash"] = _make_button(&"dig_dash", BURST_ICON, BUTTON_SIZE, "")
	_buttons[&"interact"] = _make_button(&"interact", null, SMALL_BUTTON_SIZE, "USE")
	_layout()

func _make_circle(size: float, alpha: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = CIRCLE_TEX
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = Vector2(size, size)
	t.modulate = Color(1, 1, 1, alpha)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _make_button(action: StringName, icon: Texture2D, size: float, text: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(size, size)
	add_child(root)
	root.add_child(_make_circle(size, 0.55))
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size = Vector2(size, size) * 0.56
		icon_rect.position = (Vector2(size, size) - icon_rect.size) * 0.5
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon_rect)
	elif text != "":
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(size, size)
		label.add_theme_font_size_override("font_size", int(size * 0.26))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(label)
	return root

func _layout() -> void:
	if _stick_base == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_stick_base.position = Vector2(SCREEN_MARGIN, vp.y - SCREEN_MARGIN - STICK_SIZE)
	var dash: Control = _buttons[&"dig_dash"]
	var talk: Control = _buttons[&"interact"]
	dash.position = Vector2(vp.x - SCREEN_MARGIN - BUTTON_SIZE, vp.y - SCREEN_MARGIN - BUTTON_SIZE)
	talk.position = Vector2(dash.position.x + (BUTTON_SIZE - SMALL_BUTTON_SIZE) * 0.5, dash.position.y - SMALL_BUTTON_SIZE - BUTTON_GAP)
	_update_knob()

func stick_rect() -> Rect2:
	return _stick_base.get_global_rect()

func button_rect(action: StringName) -> Rect2:
	return (_buttons[action] as Control).get_global_rect()

func is_over_control(pos: Vector2) -> bool:
	# While hidden (a menu scene, or controls off) nothing belongs to the
	# overlay, so clicks and taps pass straight through to whatever is on screen.
	if not visible:
		return false
	if _stick_base.get_global_rect().has_point(pos):
		return true
	for action in _buttons:
		if (_buttons[action] as Control).get_global_rect().has_point(pos):
			return true
	return false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_begin(event.index, event.position)
		else:
			_touch_end(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_update_stick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		# A touch is also delivered as an emulated mouse click. Anything that
		# lands on a control belongs to it, so keep the click away from the
		# world. (mole.gd guards its own _input handler separately:
		# set_input_as_handled() does not stop other _input callbacks.)
		if is_over_control(event.position):
			get_viewport().set_input_as_handled()

func _touch_begin(index: int, pos: Vector2) -> void:
	if _stick_base.get_global_rect().has_point(pos):
		_touches[index] = &"stick"
		_stick_touch = index
		_update_stick(pos)
		return
	for action in _buttons:
		if (_buttons[action] as Control).get_global_rect().has_point(pos):
			_touches[index] = action
			_send(action, true)
			return
	_touches[index] = &"world"
	if _world_touch == -1:
		_world_touch = index
		_send(&"dig_slash", true)

func _touch_end(index: int) -> void:
	if not _touches.has(index):
		return
	var held = _touches[index]
	_touches.erase(index)
	match held:
		&"stick":
			_stick_touch = -1
			_reset_stick()
		&"world":
			if _world_touch == index:
				_world_touch = -1
				_send(&"dig_slash", false)
		_:
			_send(held, false)

func _update_stick(pos: Vector2) -> void:
	var center := _stick_base.get_global_rect().get_center()
	var v := (pos - center) / STICK_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	var mag := v.length()
	if mag < STICK_DEADZONE:
		v = Vector2.ZERO
	else:
		# Rescale so the stick ramps from zero right after the deadzone up to
		# full deflection at the rim, instead of jumping to part speed.
		v = v.normalized() * ((mag - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))
	_stick_vector = v
	_apply_stick()
	_update_jump()
	_update_knob()

func _reset_stick() -> void:
	_stick_vector = Vector2.ZERO
	_apply_stick()
	_update_jump()
	_update_knob()

## Pushing the stick up jumps: it holds ui_accept down like the jump button
## used to, so the mole's jump and jump-cut (both polled from the action state)
## behave exactly as they do with the keyboard. No synthetic events here -
## ui_accept release events would read as clicks on any focused UI.
func _update_jump() -> void:
	var want := -_stick_vector.y >= JUMP_TRIGGER
	if want == _jump_held:
		return
	_jump_held = want
	if want:
		Input.action_press(&"ui_accept", 1.0)
	else:
		Input.action_release(&"ui_accept")

func _update_knob() -> void:
	if _stick_knob == null:
		return
	var center := _stick_base.position + Vector2(STICK_SIZE, STICK_SIZE) * 0.5
	_stick_knob.position = center - Vector2(STICK_KNOB_SIZE, STICK_KNOB_SIZE) * 0.5 + _stick_vector * STICK_RADIUS

func _apply_stick() -> void:
	_set_axis(&"ui_left", maxf(0.0, -_stick_vector.x))
	_set_axis(&"ui_right", maxf(0.0, _stick_vector.x))
	_set_axis(&"ui_up", maxf(0.0, -_stick_vector.y))
	_set_axis(&"ui_down", maxf(0.0, _stick_vector.y))

## Movement is polled through Input.get_axis/get_vector, which read action
## strength, so the stick feeds those continuously. Synthetic events are only
## sent when a direction starts or stops being held: listeners that count
## events (the whack-a-mole grid) step once per push, like a key press.
func _set_axis(action: StringName, strength: float) -> void:
	var previous: float = _axis_strength[action]
	_axis_strength[action] = strength
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
	if (previous > 0.0) != (strength > 0.0):
		_emit_action_event(action, strength > 0.0, 1.0 if strength > 0.0 else 0.0)

func _send(action: StringName, pressed: bool) -> void:
	if not InputMap.has_action(action):
		# "dig_dash" only exists once the mole has registered it; a button
		# press outside a level must not spam errors about it.
		return
	if pressed:
		Input.action_press(action, 1.0)
	else:
		Input.action_release(action)
	_emit_action_event(action, pressed, 1.0 if pressed else 0.0)

func _emit_action_event(action: StringName, pressed: bool, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

## Safety cleanup for when the overlay goes away mid-touch (focus loss, or
## hiding over a menu scene). Releases the action STATE only - injecting
## release events here would reach focused UI as fresh input: a released
## ui_accept on the focused menu checkbox reads as a click, which re-runs this
## very cleanup and the two keep triggering each other.
func _release_everything() -> void:
	for action in _buttons.keys():
		if InputMap.has_action(action):
			Input.action_release(action)
	# The stick holds the jump down too (see _update_jump).
	_jump_held = false
	Input.action_release(&"ui_accept")
	if InputMap.has_action(&"dig_slash"):
		Input.action_release(&"dig_slash")
	for action in STICK_ACTIONS:
		_axis_strength[action] = 0.0
		Input.action_release(action)
	_touches.clear()
	_stick_touch = -1
	_world_touch = -1
	_stick_vector = Vector2.ZERO
	_update_knob()

func _notification(what: int) -> void:
	# A focus-out or pause mid-touch must not leave a button stuck down.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_everything()
