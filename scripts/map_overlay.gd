extends CanvasLayer

## Toggleable map screen. Pressing M fades in a dimmed overlay with a "MAP"
## title and the current level's map art centred as the menu body, and pressing
## M again takes it away. The game is paused while it is up.
##
## Art is looked up per scene so each place shows its own map. A scene with no
## art of its own falls back to the design image rather than showing nothing.
##
## Under the art is a travel list: every respawn station the mole has banked
## becomes a portal that can be selected here, and picking one plays a
## teleportation and hands off to the normal circle wipe. The set of portals
## lives in Progress; this menu only reads it.

## Shown when a scene has no banked station yet, so the panel is never a blank box.
const NO_PORTALS_HINT := "BANK A RESPAWN STATION TO UNLOCK TRAVEL"

## Width of the travel panel, fixed so every button lines up under the title.
const PORTAL_PANEL_WIDTH := 300

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
## True once a portal has been picked and travel is underway, so the close
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

## The travel list. Every station the mole has banked shows up as a button; the
## scene you are already standing in is marked and disabled so it cannot send
## you where you are.
func _build_portal_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_portal_style())

	# The list is a fixed-width column; the scene currently in view is
	# highlighted and disabled rather than hidden, so the player can see where
	# they are in the set of unlocked portals.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "TRAVEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 24, Color(0.62, 0.9, 1.0, 1))
	vbox.add_child(title)

	var current := _current_scene_path()
	var portals := Progress.get_active_portals()
	if portals.is_empty():
		var empty := Label.new()
		empty.text = NO_PORTALS_HINT
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(PORTAL_PANEL_WIDTH, 0)
		_style_label(empty, 18, Color(0.72, 0.72, 0.72, 0.9))
		vbox.add_child(empty)
		return panel

	# Longest name first would look ragged, so the list is ordered by level
	# number where one exists and by scene name where it does not.
	var paths := portals.keys()
	paths.sort_custom(_compare_portal_paths)

	for path in paths:
		vbox.add_child(_make_portal_button(str(path), str(path) == current))

	return panel

func _compare_portal_paths(a: Variant, b: Variant) -> bool:
	var info_a := LevelData.get_info(str(a))
	var info_b := LevelData.get_info(str(b))
	var number_a := int(info_a.get("number", 999))
	var number_b := int(info_b.get("number", 999))
	if number_a != number_b:
		return number_a < number_b
	return _portal_label(str(a)) < _portal_label(str(b))

## Button for one unlocked destination.
func _make_portal_button(scene_path: String, is_current: bool) -> Button:
	var button := Button.new()
	button.text = ("HERE  -  " if is_current else "") + _portal_label(scene_path)
	button.custom_minimum_size = Vector2(PORTAL_PANEL_WIDTH, 44)
	button.add_theme_font_override("font", load(FONT_PATH) as Font)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58, 1) if is_current else Color(0.98, 0.94, 0.86, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_stylebox_override("normal", _make_portal_button_style(is_current))
	button.add_theme_stylebox_override("hover", _make_portal_button_style(false))
	button.add_theme_stylebox_override("pressed", _make_portal_button_style(false))
	button.add_theme_stylebox_override("focus", _make_portal_button_style(false))
	button.add_theme_stylebox_override("disabled", _make_portal_button_style(true))
	button.disabled = is_current
	button.mouse_entered.connect(_on_portal_hovered)
	if not is_current:
		button.pressed.connect(_travel_to.bind(scene_path))
	return button

## Human-readable name for a destination. LevelData covers the numbered levels;
## the hub scenes fall back to a tidied-up file name. "The Arena" and
## "Slime Valley" keep their capitalisation - `capitalize()` would flatten the
## interior words to lowercase, which is wrong for these proper nouns.
func _portal_label(scene_path: String) -> String:
	var info := LevelData.get_info(scene_path)
	if info.has("name"):
		return str(info["name"])
	var file := scene_path.get_file()
	if file.ends_with(".tscn"):
		file = file.trim_suffix(".tscn")
	return _title_words(file.replace("_", " "))

## Uppercases the first letter of each space-separated word, leaving the rest
## of the word as it was written.
func _title_words(text: String) -> String:
	var words := text.split(" ", false)
	for i in words.size():
		words[i] = words[i].substr(0, 1).to_upper() + words[i].substr(1)
	return " ".join(words)

func _on_portal_hovered() -> void:
	SFX.play_ui("ui_hover", -18.0, 1.8)

## Arrives the mole on this scene's station pad. The station plays the
## materialise animation, so travel and a death retry read identically.
func _travel_to(scene_path: String) -> void:
	if _traveling or scene_path.is_empty():
		return
	if not Progress.is_portal_active(scene_path):
		return
	if not ResourceLoader.exists(scene_path):
		return
	_traveling = true
	SFX.play_ui("ui_click")
	# Bank the destination as the respawn so a death here also returns to the
	# pad the mole was just sent to, and set the flag that tells the station to
	# play its arrival animation.
	Progress.set_respawn(scene_path, _portal_spawn(scene_path))
	Progress.respawn_pending = true
	Inventory.current_level_path = scene_path
	_play_teleport_flash()
	# The overlay has to come down before the wipe takes over, but the tree
	# stays paused across the handoff so the level behind never runs on.
	_teardown_overlay()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(scene_path)

## The stored pad position for a destination, or the origin if the record is
## missing (which only happens if a scene was removed after being banked).
func _portal_spawn(scene_path: String) -> Vector2:
	var pos = Progress.get_active_portals().get(scene_path, Vector2.ZERO)
	return pos if pos is Vector2 else Vector2.ZERO

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

## Button face for the travel list. `dimmed` marks the destination the mole is
## already standing in, so it reads as a status line rather than a target.
func _make_portal_button_style(dimmed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.15, 1) if dimmed else Color(0.2, 0.29, 0.34, 1)
	sb.border_color = Color(0.28, 0.32, 0.36, 1) if dimmed else Color(0.55, 0.82, 0.95, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb
