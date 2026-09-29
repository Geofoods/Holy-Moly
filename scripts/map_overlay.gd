extends CanvasLayer

const FONT_PATH := "res://Baby Doll.otf"
const MARKER_SIZE := 30.0
const MAP_CANVAS_SIZE := Vector2i(1260, 1050)
const GRID_COLUMNS := 3
const CARD_SIZE := Vector2(400.0, 160.0)
const CARD_GAP := Vector2(8.0, 8.0)
const GRID_ORIGIN := Vector2(10.0, 10.0)
const MAP_INSET := Vector2(8.0, 44.0)
const MAP_AREA_SIZE := Vector2(384.0, 108.0)

var _open := false
var _root: Control = null
var _holder: Control = null
var _marker: TextureRect = null
var _map_vs: SubViewport = null
var _current_map_rect := Rect2()
var _current_world_origin := Vector2.ZERO
var _current_world_size := Vector2.ONE

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
	_update_player_marker()

func _open_map() -> void:
	if _open or get_tree().paused:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var screen_size := get_viewport().get_visible_rect().size
	var display_scale := minf(screen_size.x * 0.94 / float(MAP_CANVAS_SIZE.x), screen_size.y * 0.78 / float(MAP_CANVAS_SIZE.y))
	if display_scale <= 0.0:
		return

	_open = true
	get_tree().paused = true
	_build_map_overlay(display_scale)
	_build_all_level_previews(current_scene.scene_file_path)
	_update_player_marker()

func _build_map_overlay(display_scale: float) -> void:
	_root = Control.new()
	_root.name = "MapOverlay"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.88)
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
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "ALL LEVELS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 40, Color(1.0, 0.92, 0.72, 1.0))
	vbox.add_child(title)

	var map_box := PanelContainer.new()
	map_box.add_theme_stylebox_override("panel", _make_map_style())
	vbox.add_child(map_box)

	_holder = Control.new()
	_holder.size = Vector2(MAP_CANVAS_SIZE) * display_scale
	_holder.custom_minimum_size = _holder.size
	_holder.clip_contents = true
	map_box.add_child(_holder)

	_map_vs = SubViewport.new()
	_map_vs.name = "AllLevelMaps"
	_map_vs.size = MAP_CANVAS_SIZE
	_map_vs.transparent_bg = true
	_map_vs.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_map_vs)

	var map_texture := TextureRect.new()
	map_texture.texture = _map_vs.get_texture()
	map_texture.size = _holder.size
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_SCALE
	map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(map_texture)

	var hint := Label.new()
	hint.text = "PRESS M TO CLOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 18, Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(hint)

	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _build_all_level_previews(current_path: String) -> void:
	var preview_root := Node2D.new()
	_map_vs.add_child(preview_root)
	var current_level_found := false
	var card_titles: Array[Dictionary] = []
	var paths: Array = Progress.ACORN_LEVELS

	for i in paths.size():
		var scene_path := str(paths[i])
		var card_pos := GRID_ORIGIN + Vector2(i % GRID_COLUMNS, int(i / GRID_COLUMNS)) * (CARD_SIZE + CARD_GAP)
		var card_rect := Rect2(card_pos, CARD_SIZE)
		var map_rect := Rect2(card_pos + MAP_INSET, MAP_AREA_SIZE)
		var level_info: Dictionary = LevelData.get_info(scene_path)
		var level_number := int(level_info.get("number", i + 1))
		var level_name := str(level_info.get("name", "Level %d" % level_number)).to_upper()
		var is_current := scene_path == current_path
		_add_level_card(card_rect, is_current, Progress.is_level_complete(scene_path))
		card_titles.append({"rect": card_rect, "title": "%02d  %s" % [level_number, level_name], "current": is_current})

		if not ResourceLoader.exists(scene_path):
			_add_unavailable_label(card_rect)
			continue
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			_add_unavailable_label(card_rect)
			continue
		# Preview instances stay detached so level scripts never start or spawn enemies.
		var source_scene := packed_scene.instantiate()
		var tilemap := _find_preview_tilemap(source_scene)
		var preview_data: Dictionary = {}
		if tilemap != null:
			preview_data = _add_tilemap_preview(preview_root, tilemap, map_rect)
		else:
			preview_data = _add_geometry_preview(preview_root, source_scene, map_rect)
		if preview_data.is_empty():
			_add_unavailable_label(card_rect)
		elif is_current:
			current_level_found = true
			_current_world_origin = preview_data["origin"]
			_current_world_size = preview_data["size"]
			_current_map_rect = preview_data["map_rect"]
		source_scene.free()

	if current_path == "res://scenes/level_hive.tscn":
		_add_unavailable_label(Rect2(GRID_ORIGIN + Vector2(2, 2) * (CARD_SIZE + CARD_GAP), CARD_SIZE))
	for card in card_titles:
		_add_level_card_title(card["rect"], card["title"], card["current"])
	if current_level_found:
		_add_player_marker()
	else:
		_current_map_rect = Rect2()
		_current_world_origin = Vector2.ZERO
		_current_world_size = Vector2.ONE

func _add_tilemap_preview(preview_root: Node2D, source: TileMap, map_rect: Rect2) -> Dictionary:
	var used_rect := source.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0 or source.tile_set == null:
		return {}
	var tile_size := Vector2(source.tile_set.tile_size)
	var source_scale := source.global_scale
	var world_size := Vector2(used_rect.size) * tile_size * source_scale.abs()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return {}

	var fit := minf(map_rect.size.x / world_size.x, map_rect.size.y / world_size.y)
	var fitted_size := world_size * fit
	var map_origin := map_rect.position + (map_rect.size - fitted_size) * 0.5
	var local_origin := source.map_to_local(used_rect.position) - tile_size * 0.5
	var copy := source.duplicate() as TileMap
	if copy == null:
		return {}
	copy.set_script(null)
	copy.rotation = source.global_rotation
	copy.scale = source_scale * fit
	var transformed_origin := Vector2(local_origin.x * copy.scale.x, local_origin.y * copy.scale.y).rotated(copy.rotation)
	copy.position = map_origin - transformed_origin
	preview_root.add_child(copy)
	return {"origin": source.to_global(local_origin), "size": world_size, "map_rect": Rect2(map_origin, fitted_size)}

func _add_geometry_preview(preview_root: Node2D, source_scene: Node, map_rect: Rect2) -> Dictionary:
	var outlines: Array[PackedVector2Array] = []
	var limits: Array[float] = [INF, INF, -INF, -INF]
	_collect_static_rectangles(source_scene, outlines, limits)
	if outlines.is_empty() or limits[0] == INF or limits[2] <= limits[0] or limits[3] <= limits[1]:
		return {}
	var world_origin := Vector2(limits[0], limits[1])
	var world_size := Vector2(limits[2] - limits[0], limits[3] - limits[1])
	var fit := minf(map_rect.size.x / world_size.x, map_rect.size.y / world_size.y)
	var fitted_size := world_size * fit
	var map_origin := map_rect.position + (map_rect.size - fitted_size) * 0.5
	for points in outlines:
		var line := Line2D.new()
		line.width = 2.5
		line.default_color = Color(0.82, 0.68, 0.9, 0.95)
		line.closed = true
		line.z_index = 2
		for point in points:
			line.add_point(map_origin + (point - world_origin) * fit)
		preview_root.add_child(line)
	return {"origin": world_origin, "size": world_size, "map_rect": Rect2(map_origin, fitted_size)}

func _collect_static_rectangles(node: Node, outlines: Array[PackedVector2Array], limits: Array[float]) -> void:
	if node is CollisionShape2D and node.get_parent() is StaticBody2D:
		var collision_shape := node as CollisionShape2D
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle != null:
			var half := rectangle.size * 0.5
			var points := PackedVector2Array()
			for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
				var point: Vector2 = collision_shape.to_global(corner)
				points.append(point)
				limits[0] = minf(limits[0], point.x)
				limits[1] = minf(limits[1], point.y)
				limits[2] = maxf(limits[2], point.x)
				limits[3] = maxf(limits[3], point.y)
			outlines.append(points)
	for child in node.get_children():
		_collect_static_rectangles(child, outlines, limits)

func _find_preview_tilemap(node: Node) -> TileMap:
	if node == null:
		return null
	if node is TileMap:
		var tilemap := node as TileMap
		if tilemap.tile_set != null and tilemap.get_used_rect().size.x > 0 and tilemap.get_used_rect().size.y > 0:
			return tilemap
	for child in node.get_children():
		var found := _find_preview_tilemap(child)
		if found != null:
			return found
	return null

func _add_level_card(card_rect: Rect2, is_current: bool, is_complete: bool) -> void:
	var shade := ColorRect.new()
	shade.position = card_rect.position
	shade.size = card_rect.size
	shade.color = Color(0.03, 0.025, 0.06, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(shade)

	var border := Panel.new()
	border.position = card_rect.position
	border.size = card_rect.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_color := Color(1.0, 0.82, 0.28, 1.0) if is_current else Color(0.45, 0.35, 0.24, 0.95)
	if is_complete and not is_current:
		border_color = Color(0.45, 0.78, 0.35, 0.95)
	border.add_theme_stylebox_override("panel", _make_card_style(border_color))
	_holder.add_child(border)

func _add_level_card_title(card_rect: Rect2, title: String, is_current: bool) -> void:
	var header := ColorRect.new()
	header.position = card_rect.position
	header.size = Vector2(card_rect.size.x, 42.0)
	header.color = Color(0.07, 0.045, 0.1, 0.96)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(header)
	var label := Label.new()
	label.position = card_rect.position + Vector2(10.0, 3.0)
	label.size = Vector2(card_rect.size.x - 20.0, 36.0)
	label.text = title + ("  • CURRENT" if is_current else "")
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(label, 19, Color(1.0, 0.9, 0.67, 1.0) if is_current else Color(0.94, 0.9, 0.82, 1.0))
	_holder.add_child(label)

func _add_unavailable_label(card_rect: Rect2) -> void:
	var label := Label.new()
	label.position = card_rect.position + Vector2(8.0, 84.0)
	label.size = Vector2(card_rect.size.x - 16.0, 48.0)
	label.text = "MAP DATA UNAVAILABLE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(label, 17, Color(0.72, 0.65, 0.62, 0.95))
	_holder.add_child(label)

func _add_player_marker() -> void:
	_marker = TextureRect.new()
	_marker.name = "PlayerMapMarker"
	_marker.texture = _make_marker_tex()
	_marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	_marker.z_index = 20
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_marker)

func _update_player_marker() -> void:
	if not _open or _marker == null or _current_map_rect.size == Vector2.ZERO:
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or _current_world_size == Vector2.ZERO:
		return
	var fraction := (mole.global_position - _current_world_origin) / _current_world_size
	var map_position := _current_map_rect.position + Vector2(clampf(fraction.x, 0.0, 1.0), clampf(fraction.y, 0.0, 1.0)) * _current_map_rect.size
	_marker.position = map_position - _marker.size * 0.5

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
	_current_map_rect = Rect2()
	_current_world_origin = Vector2.ZERO
	_current_world_size = Vector2.ONE

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
	sb.bg_color = Color(0.18, 0.12, 0.22, 0.98)
	sb.border_color = Color(0.62, 0.45, 0.72, 1.0)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.shadow_size = 18
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	return sb

func _make_card_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	return style

func _make_map_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.045, 0.08, 1.0)
	sb.border_color = Color(0.38, 0.29, 0.45, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	return sb