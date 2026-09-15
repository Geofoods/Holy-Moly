extends CanvasLayer

const FONT_PATH := "res://Baby Doll.otf"
const MARKER_SIZE := 24.0

var _open := false
var _root: Control = null
var _holder: Control = null
var _marker: TextureRect = null
var _map_vs: SubViewport = null
var _map_tex: Texture2D = null
var _frac_offset := Vector2.ZERO
var _frac_scale := Vector2.ONE

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

func _process(_delta: float) -> void:
	if not _open or _marker == null:
		return
	var mole = get_tree().get_first_node_in_group("mole")
	if mole == null or _frac_scale == Vector2.ZERO:
		return
	var frac: Vector2 = (mole.global_position - _frac_offset) / _frac_scale
	_marker.position = Vector2(clampf(frac.x, 0.0, 1.0), clampf(frac.y, 0.0, 1.0)) * _holder.size - _marker.size / 2.0

func _open_map() -> void:
	if _open or get_tree().paused:
		return
	var tilemap := _find_tilemap(get_tree().current_scene)
	if tilemap == null or tilemap.tile_set == null:
		return
	var rect := tilemap.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var tile_size := Vector2(float(tilemap.tile_set.tile_size.x), float(tilemap.tile_set.tile_size.y))
	var world_scale := tilemap.scale
	var map_px: Vector2 = Vector2(float(rect.size.x), float(rect.size.y)) * tile_size * world_scale

	var k := 1.0
	var max_dim := 1600.0
	if map_px.x > max_dim or map_px.y > max_dim:
		k = minf(max_dim / map_px.x, max_dim / map_px.y)
	var vp_size := Vector2i(maxi(int(ceil(map_px.x * k)), 1), maxi(int(ceil(map_px.y * k)), 1))

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

	var screen := get_viewport().get_visible_rect().size
	var max_w := screen.x * 0.72
	var max_h := screen.y * 0.72
	var ratio := minf(max_w / map_px.x, max_h / map_px.y)
	_holder = Control.new()
	_holder.size = map_px * ratio
	_holder.clip_contents = true
	map_box.add_child(_holder)

	_map_vs = SubViewport.new()
	_map_vs.size = vp_size
	_map_vs.transparent_bg = true
	_map_vs.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_map_vs)

	var dup: Node2D = tilemap.duplicate()
	var dup_scale := world_scale * k
	dup.scale = dup_scale
	dup.position = -Vector2(float(rect.position.x), float(rect.position.y)) * tile_size * dup_scale
	_map_vs.add_child(dup)

	var map_tex := TextureRect.new()
	map_tex.texture = _map_vs.get_texture()
	map_tex.size = _holder.size
	map_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_holder.add_child(map_tex)

	_map_tex = map_tex.texture

	_marker = TextureRect.new()
	_marker.texture = _make_marker_tex()
	_marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	_holder.add_child(_marker)

	_frac_offset = Vector2(float(rect.position.x), float(rect.position.y)) * tile_size * world_scale + tilemap.global_position
	_frac_scale = map_px

	var hint := Label.new()
	hint.text = "PRESS M TO CLOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 20, Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(hint)

	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_map()

func _close_map() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	if _map_vs != null:
		_map_vs.queue_free()
		_map_vs = null
	if _root != null:
		_root.queue_free()
		_root = null
	_holder = null
	_marker = null
	_map_tex = null

func _find_tilemap(node: Node) -> TileMap:
	if node == null:
		return null
	if node is TileMap:
		return node
	for child in node.get_children():
		var found := _find_tilemap(child)
		if found != null:
			return found
	return null

func _make_marker_tex() -> Texture2D:
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= 7.0:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.25, 1))
			elif d <= 9.0:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08, 1))
	return ImageTexture.create_from_image(img)

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