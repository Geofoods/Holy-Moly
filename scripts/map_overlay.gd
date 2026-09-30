extends CanvasLayer

## Toggleable map screen. Pressing M fades in a dimmed overlay with a "MAP"
## title and the current level's map art centred as the menu body, and pressing
## M again takes it away. The game is paused while it is up.
##
## Art is looked up per scene so each place shows its own map. A scene with no
## art of its own falls back to the design image rather than showing nothing.
##
## Under the art is a travel list: the two hub scenes can each be selected here,
## and picking one plays a teleportation and hands off to the normal circle
## wipe. Both are available from the first frame - there is nothing to unlock -
## and each hub owns a respawn station, so arriving drops the mole onto its pad
## and plays the same arrival animation a death retry does.

## Width of the travel panel, fixed so every button lines up under the title.
const PORTAL_PANEL_WIDTH := 300

## The travel destinations, in the order they are listed. `path` is the scene to
## load; `label` is what the button says. The labels are written out rather than
## derived from the file names because neither hub has a LevelData entry, which
## used to fall back to tidied file names and render them as "Molevillage" and
## "Shopkeeper Item".
const TRAVEL_HUBS: Array[Dictionary] = [
	{"path": "res://scenes/molevillage.tscn", "label": "Mole Village"},
	{"path": "res://scenes/shopkeeper_item.tscn", "label": "Mole Shopkeeper"},
]

## Where the mole has been, the mole has to have got there on foot first, so a
## destination is only offered once Progress records a visit. Both hubs own a
## respawn station, so arriving drops the mole onto its pad.
const LOCKED_SUFFIX := "  ·  NOT VISITED"

## Button states. A destination the mole is standing in reads as a status line
## rather than a target, and one it has never reached reads as still out there.
const STATE_OPEN := 0
const STATE_HERE := 1
const STATE_LOCKED := 2

## How long the departure flash sits on screen before the wipe starts.
const TELEPORT_FLASH := 0.28
## White flash the departing mole leaves behind, matching the arrival burst.
const TELEPORT_FLASH_COLOR := Color(0.62, 0.95, 1.0, 0.9)

const FONT_PATH := "res://Baby Doll.otf"
## Shown when the current scene has no art of its own.
const MAP_FALLBACK := "res://mapdesign.png"
## Which map belongs to which scene.
const SCENE_MAPS := {
	"res://scenes/molevillage.tscn": "res://Untitled design (1)/molevillage.png",
	"res://scenes/tutorial.tscn": "res://Untitled design (1)/tutorial.png",
	"res://scenes/shopkeeper_item.tscn": "res://Untitled design (1)/shopkeeper_item.png",
	"res://scenes/Slime Valley.tscn": "res://Untitled design (1)/slime_valley.png",
	"res://scenes/The Arena.tscn": "res://Untitled design (1)/the arena.png",
	"res://scenes/level_02.tscn": "res://Untitled design (1)/level2.png",
	"res://scenes/level_03.tscn": "res://Untitled design (1)/level3.png",
	"res://scenes/level_04.tscn": "res://Untitled design (1)/level4.png",
	"res://scenes/level_05.tscn": "res://Untitled design (1)/level5.png",
	"res://scenes/level_06.tscn": "res://Untitled design (1)/level6.png",
	"res://scenes/level_07.tscn": "res://Untitled design (1)/level7.png",
	"res://scenes/level_08.tscn": "res://Untitled design (1)/level8.png",
	"res://scenes/level_09.tscn": "res://Untitled design (1)/level9.png",
	"res://scenes/level_10.tscn": "res://Untitled design (1)/level10.png",
}
## Fraction of the smaller screen axis the art is fitted into, leaving room for
## the title above and the hint below.
const MAP_ART_FILL := 0.6
## How long the overlay takes to fade in, and to fade back out again on close.
const MAP_FADE_TIME := 0.18

var _open := false
## True while the fade-out is playing. The overlay is still on screen and the
## tree is still paused, so it must not be treated as closed yet.
var _closing := false
## True once a destination has been picked and travel is underway, so the close
## paths and M cannot interrupt a teleport already committed to.
var _traveling := false
var _root: Control = null
var _holder: Control = null
var _art: Texture2D = null

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)

## Travel sets `_traveling` and hands off to the scene wipe, which outlives
## this autoload, so the flag has to be cleared once the destination is actually
## in. Without this the map could only ever be opened once per session.
func _on_scene_changed() -> void:
	_traveling = false

func _unhandled_input(event: InputEvent) -> void:
	if _traveling:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			if _open:
				_close_map()
			else:
				_open_map()

## Other menus pause the tree too, and they must not fight this one over the
## shared paused flag - otherwise one closing would unpause the other's screen.
func is_map_open() -> bool:
	return _open

func _open_map() -> void:
	if _open or _traveling or get_tree().paused:
		return

	_open = true
	get_tree().paused = true

	_root = Control.new()
	_root.name = "MapOverlay"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 44, Color(1.0, 0.92, 0.72, 1))
	vbox.add_child(title)

	var map_box := PanelContainer.new()
	map_box.add_theme_stylebox_override("panel", _make_map_style())
	vbox.add_child(map_box)

	_art = _current_map_art()
	_holder = Control.new()
	_holder.custom_minimum_size = _map_art_size()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_box.add_child(_holder)

	var art := TextureRect.new()
	art.texture = _art
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(art)

	var hint := Label.new()
	hint.text = "PRESS M TO CLOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 20, Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(hint)

	vbox.add_child(_build_portal_panel())

	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, MAP_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The travel list. Both hubs are always listed, but one the mole has never
## reached is shown locked; the scene the mole is already standing in is marked
## and disabled so it cannot send you where you are.
func _build_portal_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_portal_style())

	# The list is a fixed-width column; the scene currently in view is
	# highlighted and disabled rather than hidden, so the player can see where
	# they are in the set of destinations.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "TRAVEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 24, Color(0.62, 0.9, 1.0, 1))
	vbox.add_child(title)

	var current := _current_scene_path()
	for hub in TRAVEL_HUBS:
		var path := str(hub["path"])
		vbox.add_child(_make_portal_button(path, str(hub["label"]), _portal_state(path, current)))

	return panel

## Where a destination sits in the three states. Being the current scene wins
## over everything, so standing in an unvisited hub still shows as HERE.
func _portal_state(scene_path: String, current: String) -> int:
	if scene_path == current:
		return STATE_HERE
	if Progress.has_visited(scene_path):
		return STATE_OPEN
	return STATE_LOCKED

## Button for one travel destination.
func _make_portal_button(scene_path: String, label: String, state: int) -> Button:
	var button := Button.new()
	button.text = _portal_button_text(label, state)
	button.custom_minimum_size = Vector2(PORTAL_PANEL_WIDTH, 44)
	button.add_theme_font_override("font", load(FONT_PATH) as Font)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", _portal_text_color(state))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	# HERE and LOCKED are both disabled, and a disabled Button reads this slot
	# rather than font_color, so it has to be set for the states to look right.
	button.add_theme_color_override("font_disabled_color", _portal_text_color(state))
	button.add_theme_stylebox_override("normal", _make_portal_button_style(state))
	button.add_theme_stylebox_override("hover", _make_portal_button_style(STATE_OPEN))
	button.add_theme_stylebox_override("pressed", _make_portal_button_style(STATE_OPEN))
	button.add_theme_stylebox_override("focus", _make_portal_button_style(STATE_OPEN))
	button.add_theme_stylebox_override("disabled", _make_portal_button_style(state))
	button.disabled = state != STATE_OPEN
	button.mouse_entered.connect(_on_portal_hovered)
	if state == STATE_OPEN:
		button.pressed.connect(_travel_to.bind(scene_path))
	return button

## Button caption for one state. The locked suffix says why it is locked, so a
## greyed-out destination reads as somewhere still to find rather than a bug.
func _portal_button_text(label: String, state: int) -> String:
	match state:
		STATE_HERE:
			return "HERE  -  " + label
		STATE_LOCKED:
			return label + LOCKED_SUFFIX
		_:
			return label

func _portal_text_color(state: int) -> Color:
	match state:
		STATE_HERE:
			return Color(0.72, 0.66, 0.58, 1)
		STATE_LOCKED:
			return Color(0.48, 0.5, 0.54, 1)
		_:
			return Color(0.98, 0.94, 0.86, 1)

func _on_portal_hovered() -> void:
	SFX.play_ui("ui_hover", -18.0, 1.8)

## Arrives the mole on the destination hub's station pad. The station plays the
## materialise animation, so travel and a death retry read identically.
func _travel_to(scene_path: String) -> void:
	if _traveling or scene_path.is_empty():
		return
	# Re-checked here as well as on the button, so a locked destination cannot be
	# reached by anything that presses it without going through the list.
	if not Progress.has_visited(scene_path):
		return
	if not ResourceLoader.exists(scene_path):
		return
	_traveling = true
	SFX.play_ui("ui_click")
	# Bank the destination as the respawn so a death there also returns to the
	# hub, and set the flag that tells the station to play its arrival
	# animation. No position is recorded: both hubs have a single station, and
	# the one in the destination scene works the arrival spot out from its own
	# pad, so there is nothing here that has to agree with it.
	Progress.set_respawn(scene_path, Vector2.ZERO)
	Progress.respawn_pending = true
	Inventory.current_level_path = scene_path
	_play_teleport_flash()
	# The overlay has to come down before the wipe takes over, but the tree
	# stays paused across the handoff so the level behind never runs on.
	_teardown_overlay()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(scene_path)

## A quick bloom where the mole stood, so leaving reads as a teleport rather
## than a hard cut into the circle wipe. Bound to the map layer, which is
## PROCESS_MODE_ALWAYS, so it still animates while the tree is paused.
func _play_teleport_flash() -> void:
	var flash := ColorRect.new()
	flash.color = TELEPORT_FLASH_COLOR
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, TELEPORT_FLASH * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, TELEPORT_FLASH * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(flash.queue_free)

## Removes the overlay without unpausing. Used by travel, which hands the pause
## straight to the scene wipe, so the mole's scene is never left running.
func _teardown_overlay() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_holder = null
	_open = false
	_closing = false

func _current_scene_path() -> String:
	var current := get_tree().current_scene as Node
	return "" if current == null else str(current.scene_file_path)

## The art for the scene the player is standing in. Looks the path up rather
## than reading a level number, so hub scenes and the arena can have art too.
##
## Loaded at runtime rather than preloaded because the art lives in a folder
## name containing a space and parentheses, and because scenes with no art of
## their own still have to open. ResourceLoader.exists guards each step, so a
## missing or unimported file quietly falls back instead of erroring out.
func _current_map_art() -> Texture2D:
	var path := _current_scene_path()
	var art_path := str(SCENE_MAPS.get(path, ""))
	if art_path.is_empty() or not ResourceLoader.exists(art_path):
		art_path = MAP_FALLBACK
	var texture := load(art_path) as Texture2D
	return texture if texture != null else null

## The art fitted to the screen while keeping its aspect ratio.
func _map_art_size() -> Vector2:
	var screen := get_viewport().get_visible_rect().size
	var extent := minf(screen.x, screen.y) * MAP_ART_FILL
	if _art == null:
		return Vector2(extent, extent)
	var art_size := _art.get_size()
	if art_size.x <= 0.0 or art_size.y <= 0.0:
		return Vector2(extent, extent)
	var scale_factor := minf(extent / art_size.x, extent / art_size.y)
	return art_size * scale_factor

func _on_root_gui_input(event: InputEvent) -> void:
	if _traveling:
		return
	if event is InputEventMouseButton and event.pressed:
		_close_map()

func _close_map() -> void:
	# The tree stays paused for the whole fade-out, so _open has to stay true
	# until the overlay is actually gone. Anything else that pauses the tree
	# would otherwise see the map as closed and race this unpause.
	if not _open or _closing or _traveling:
		return
	_closing = true
	if _root == null:
		_finish_close()
		return
	var closing := _root
	var tween := create_tween()
	tween.tween_property(closing, "modulate:a", 0.0, MAP_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_close.bind(closing))

## Tears the overlay down once it has finished fading out.
func _finish_close(closing: Control = null) -> void:
	if closing != null and is_instance_valid(closing):
		closing.queue_free()
	_closing = false
	_open = false
	if _root == closing or closing == null:
		_root = null
		_holder = null
	get_tree().paused = false

func _style_label(label: Label, size: int, color: Color) -> void:
	var font := load(FONT_PATH) as Font
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))

func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.14, 0.09, 0.97)
	sb.border_color = Color(0.62, 0.45, 0.22, 1)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 20
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb

func _make_map_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.05, 1)
	sb.border_color = Color(0.7, 0.52, 0.26, 1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	return sb

func _make_portal_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.15, 0.97)
	sb.border_color = Color(0.35, 0.58, 0.68, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb

## Button face for the travel list, one per state. HERE reads as a status line
## rather than a target; LOCKED sits dimmer than that, so a place still to find
## is quieter than the place the mole is standing in.
func _make_portal_button_style(state: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match state:
		STATE_HERE:
			sb.bg_color = Color(0.1, 0.12, 0.15, 1)
			sb.border_color = Color(0.28, 0.32, 0.36, 1)
		STATE_LOCKED:
			sb.bg_color = Color(0.08, 0.08, 0.1, 1)
			sb.border_color = Color(0.22, 0.23, 0.26, 1)
		_:
			sb.bg_color = Color(0.2, 0.29, 0.34, 1)
			sb.border_color = Color(0.55, 0.82, 0.95, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb
