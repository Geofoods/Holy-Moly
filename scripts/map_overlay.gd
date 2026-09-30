extends CanvasLayer

## Toggleable map screen. Pressing M fades in a dimmed overlay with a "MAP"
## title and the current level's map art centred as the menu body, and pressing
## M again takes it away. The game is paused while it is up.
##
## Art is looked up per scene so each place shows its own map. A scene with no
## art of its own falls back to the design image rather than showing nothing.

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
var _root: Control = null
var _holder: Control = null
var _art: Texture2D = null

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90

func _unhandled_input(event: InputEvent) -> void:
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
	if _open or get_tree().paused:
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

	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, MAP_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The art for the scene the player is standing in. Looks the path up rather
## than reading a level number, so hub scenes and the arena can have art too.
##
## Loaded at runtime rather than preloaded because the art lives in a folder
## name containing a space and parentheses, and because scenes with no art of
## their own still have to open. ResourceLoader.exists guards each step, so a
## missing or unimported file quietly falls back instead of erroring out.
func _current_map_art() -> Texture2D:
	var path := ""
	var current := get_tree().current_scene as Node
	if current != null:
		path = str(current.scene_file_path)
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
	if event is InputEventMouseButton and event.pressed:
		_close_map()

func _close_map() -> void:
	# The tree stays paused for the whole fade-out, so _open has to stay true
	# until the overlay is actually gone. Anything else that pauses the tree
	# would otherwise see the map as closed and race this unpause.
	if not _open or _closing:
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
