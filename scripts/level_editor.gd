extends Node2D

## "Level Forge" -- the in-game level editor.
##
## Paint blocks from the game's own TileSet and drop enemies straight from the
## campaign, then hit PLAY to test the level in place with the real mole.
##
## Levels are small JSON files under user://levels, so nothing has to be
## re-imported into the project. A working copy is autosaved on every edit,
## which is what keeps an author's work safe when a playtest ends in the game
## over screen.
##
## Controls: left click paints, right click erases, the middle mouse button
## drags the view (WASD/arrows pan too), the wheel zooms, Ctrl+Z undoes and G
## toggles the grid.

const TOOL_BLOCK := 0
const TOOL_ENEMY := 1
const TOOL_ERASE := 2
const TOOL_SPAWN := 3

const TAB_BLOCKS := 0
const TAB_ENEMIES := 1

const TILE_LAYER := 0
const TERRAIN_SOURCE := 0

const MOLE_SCENE := preload("res://scenes/mole.tscn")
const UI_FONT := preload("res://Baby Doll.otf")

const SAVE_DIR := "user://levels"
const AUTOSAVE_PATH := "user://levels/_autosave.json"
const AUTOSAVE_DELAY := 0.7
const DEFAULT_LEVEL_NAME := "Untitled Level"

## The campaign levels scale the mole down to a quarter so he stands roughly
## one tile tall next to the half-scaled 160px TileSet.
const MOLE_SCALE := Vector2(0.25, 0.25)
const MOLE_CAMERA_SCALE := Vector2(4.0, 4.0)
const MOLE_CAMERA_ZOOM := Vector2(0.65, 0.65)

const PAN_SPEED := 900.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 2.5
const UNDO_LIMIT := 40

const NEW_FLOOR_WIDTH := 12
const NEW_FLOOR_ROW := 2
const DEFAULT_SPAWN_CELL := Vector2i(6, 1)

const ENEMY_CATALOG := [
	{"name": "Ant", "scene": "res://scenes/antenemy.tscn"},
	{"name": "Bat", "scene": "res://scenes/bat_enemy.tscn"},
	{"name": "Beetle", "scene": "res://scenes/beetleenemy.tscn"},
	{"name": "Goblin", "scene": "res://scenes/goblinenemy.tscn"},
	{"name": "Hornet", "scene": "res://scenes/hornet_enemy.tscn"},
	{"name": "Mushroom", "scene": "res://scenes/mushroom_enemy.tscn"},
	{"name": "Slime", "scene": "res://scenes/slimeenemy.tscn"},
	{"name": "Snake", "scene": "res://scenes/snake_enemy.tscn"},
	{"name": "Worm", "scene": "res://scenes/worm_enemy.tscn"},
]

const PANEL_BG := Color(0.10, 0.075, 0.07, 0.94)
const PANEL_BORDER := Color(0.62, 0.44, 0.28, 1.0)
const BUTTON_BG := Color(0.22, 0.16, 0.12, 0.98)
const BUTTON_HOVER := Color(0.33, 0.23, 0.16, 1.0)
const BUTTON_PRESSED := Color(0.46, 0.32, 0.18, 1.0)
const BUTTON_DISABLED := Color(0.16, 0.13, 0.12, 0.9)
const TEXT_COLOR := Color(0.98, 0.9, 0.78, 1.0)
const ACCENT := Color(1.0, 0.84, 0.45, 1.0)

@onready var _tilemap: TileMap = $TileMap
@onready var _entities: Node2D = $Entities
@onready var _overlay: Node2D = $Overlay
@onready var _editor_camera: Camera2D = $EditorCamera
@onready var _hud: CanvasLayer = $HUD

## World size of one cell (tile_size * the TileMap's scale).
var _tile_world := 80.0

var _tiles: Dictionary = {}
var _enemies: Array = []
var _spawn_point := Vector2.ZERO
var _level_name := DEFAULT_LEVEL_NAME

var _tool := TOOL_BLOCK
var _tab := TAB_BLOCKS
var _selected_block := Vector2i.ZERO
var _selected_enemy := 0
var _show_grid := true

var _hover_cell := Vector2i(999999, 999999)
var _painting := false
var _panning := false
var _last_paint_cell := Vector2i(999999, 999999)

var _undo_stack: Array = []
var _redo_stack: Array = []

var _playing := false
var _mole: Node = null
var _mole_camera: Camera2D = null
var _pit: Area2D = null
## Nodes the borrowed mole parents above itself -- swing ghosts, the dig cursor,
## stray projectiles -- all land back inside this scene, so the child list is
## snapshotted around a playtest and the additions are swept up when it ends.
var _children_before: Array = []

var _autosave_timer: Timer = null

var _ui_root: Control = null
var _toolbar: PanelContainer = null
var _palette: PanelContainer = null
var _play_bar: PanelContainer = null
var _hint: Label = null
var _hint_panel: PanelContainer = null
var _toast_label: Label = null
var _name_edit: LineEdit = null
var _block_grid: GridContainer = null
var _enemy_grid: GridContainer = null
var _blocks_tab: Button = null
var _enemies_tab: Button = null
var _erase_btn: Button = null
var _spawn_btn: Button = null
var _grid_btn: Button = null
var _load_overlay: Control = null
var _load_list: VBoxContainer = null
var _block_buttons: Dictionary = {}
var _enemy_buttons: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_tile_world = float(_tilemap.tile_set.tile_size.x) * absf(_tilemap.scale.x)
	_overlay.editor = self

	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(_save_autosave)
	add_child(_autosave_timer)

	_build_ui()
	_setup_palette()

	if FileAccess.file_exists(AUTOSAVE_PATH):
		load_level(AUTOSAVE_PATH)
	else:
		_new_level(true)

	_editor_camera.position = _spawn_point
	_editor_camera.make_current()
	_refresh_tool_buttons()
	_hover_cell = Vector2i(999999, 999999)
	_overlay.queue_redraw()


func _exit_tree() -> void:
	_save_now()
	# The mole runs the whole campaign at 1.2x; leaving that set would speed the
	# editor (and the menus) up for the rest of the session.
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- level state

func _new_level(with_floor: bool) -> void:
	_tiles.clear()
	_enemies.clear()
	_level_name = DEFAULT_LEVEL_NAME
	if _name_edit != null:
		_name_edit.text = _level_name
	if with_floor:
		for x in NEW_FLOOR_WIDTH:
			_tiles[Vector2i(x, NEW_FLOOR_ROW)] = Vector3i(TERRAIN_SOURCE, 0, 0)
	_apply_level()
	_spawn_point = _cell_center(DEFAULT_SPAWN_CELL) + Vector2(0.0, _tile_world * 0.15)
	if _editor_camera != null:
		_editor_camera.position = _spawn_point
	_overlay.queue_redraw()


func _apply_level() -> void:
	_tilemap.clear_layer(TILE_LAYER)
	for cell in _tiles:
		var t: Vector3i = _tiles[cell]
		_tilemap.set_cell(TILE_LAYER, cell, t.x, Vector2i(t.y, t.z))
	_rebuild_enemy_nodes()
	_overlay.queue_redraw()


func _rebuild_enemy_nodes() -> void:
	for child in _entities.get_children():
		_entities.remove_child(child)
		child.queue_free()
	for entry in _enemies:
		var node := _make_enemy_node(str(entry["name"]))
		if node == null:
			continue
		_entities.add_child(node)
		node.global_position = entry["position"]
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _make_enemy_node(enemy_name: String) -> Node2D:
	for spec in ENEMY_CATALOG:
		if str(spec["name"]) == enemy_name:
			var packed := load(str(spec["scene"])) as PackedScene
			if packed != null:
				return packed.instantiate() as Node2D
	return null


# ------------------------------------------------------------------- painting

func _paint(cell: Vector2i) -> void:
	match _tool:
		TOOL_BLOCK:
			_tiles[cell] = Vector3i(TERRAIN_SOURCE, _selected_block.x, _selected_block.y)
			_tilemap.set_cell(TILE_LAYER, cell, TERRAIN_SOURCE, _selected_block)
		TOOL_ENEMY:
			var spec: Dictionary = ENEMY_CATALOG[_selected_enemy]
			_enemies.append({"name": str(spec["name"]), "position": _enemy_spot(cell)})
			_rebuild_enemy_nodes()
		TOOL_SPAWN:
			_spawn_point = _cell_center(cell) + Vector2(0.0, _tile_world * 0.15)
		TOOL_ERASE:
			_erase_cell(cell)
	_overlay.queue_redraw()
	_mark_dirty()


func _erase_cell(cell: Vector2i) -> void:
	var index := _enemy_index_at(_cell_center(cell))
	if index >= 0:
		_enemies.remove_at(index)
		_rebuild_enemy_nodes()
		return
	if _tiles.erase(cell):
		_tilemap.erase_cell(TILE_LAYER, cell)


func _enemy_index_at(point: Vector2) -> int:
	var radius := _tile_world * 0.7
	for i in range(_enemies.size() - 1, -1, -1):
		var position: Vector2 = _enemies[i]["position"]
		if position.distance_to(point) <= radius:
			return i
	return -1


func _cell_at_mouse() -> Vector2i:
	return _tilemap.local_to_map(_tilemap.to_local(get_global_mouse_position()))


func _cell_center(cell: Vector2i) -> Vector2:
	return _tilemap.to_global(_tilemap.map_to_local(cell))


func _enemy_spot(cell: Vector2i) -> Vector2:
	return _cell_center(cell) + Vector2(0.0, _tile_world * 0.35)


# -------------------------------------------------------------- undo / redo

func _snapshot() -> Dictionary:
	return {
		"tiles": _tiles.duplicate(true),
		"enemies": _enemies.duplicate(true),
		"spawn": _spawn_point,
		"name": _level_name,
	}


func _push_undo() -> void:
	_undo_stack.append(_snapshot())
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()


func _restore(snapshot: Dictionary) -> void:
	_tiles = snapshot["tiles"].duplicate(true)
	_enemies = snapshot["enemies"].duplicate(true)
	_spawn_point = snapshot["spawn"]
	_level_name = str(snapshot["name"])
	if _name_edit != null:
		_name_edit.text = _level_name
	_apply_level()


func _undo_last() -> void:
	if _undo_stack.is_empty():
		_toast("Nothing to undo")
		return
	_redo_stack.append(_snapshot())
	_restore(_undo_stack.pop_back())
	_mark_dirty()


func _redo_last() -> void:
	if _redo_stack.is_empty():
		_toast("Nothing to redo")
		return
	_undo_stack.append(_snapshot())
	_restore(_redo_stack.pop_back())
	_mark_dirty()


# ------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var blocks: Array = []
	for cell in _tiles:
		var t: Vector3i = _tiles[cell]
		blocks.append([t.x, t.y, t.z, cell.x, cell.y])
	var enemies: Array = []
	for entry in _enemies:
		var position: Vector2 = entry["position"]
		enemies.append([str(entry["name"]), position.x, position.y])
	return {
		"version": 1,
		"name": _level_name,
		"spawn": [_spawn_point.x, _spawn_point.y],
		"blocks": blocks,
		"enemies": enemies,
	}


func from_dict(data: Dictionary) -> bool:
	if not (data.has("blocks") and data.has("enemies")):
		return false
	_tiles.clear()
	_enemies.clear()
	for row in data["blocks"]:
		if row is Array and row.size() >= 5:
			var cell := Vector2i(int(row[3]), int(row[4]))
			_tiles[cell] = Vector3i(int(row[0]), int(row[1]), int(row[2]))
	for row in data["enemies"]:
		if row is Array and row.size() >= 3:
			_enemies.append({
				"name": str(row[0]),
				"position": Vector2(float(row[1]), float(row[2])),
			})
	var spawn = data.get("spawn", null)
	if spawn is Array and spawn.size() >= 2:
		_spawn_point = Vector2(float(spawn[0]), float(spawn[1]))
	else:
		_spawn_point = Vector2.ZERO
	_level_name = str(data.get("name", DEFAULT_LEVEL_NAME))
	if _name_edit != null:
		_name_edit.text = _level_name
	_apply_level()
	return true


func save_level(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


func load_level(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	return from_dict(parsed)


func _slug(text: String) -> String:
	var lower := text.strip_edges().to_lower()
	var out := ""
	for i in lower.length():
		var ch := lower.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			out += "_"
	var trimmed := out.strip_edges()
	while trimmed.begins_with("_"):
		trimmed = trimmed.substr(1)
	while trimmed.ends_with("_"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	if trimmed.is_empty():
		trimmed = "level"
	return trimmed


func _mark_dirty() -> void:
	if _autosave_timer == null:
		return
	_autosave_timer.start(AUTOSAVE_DELAY)


func _save_autosave() -> void:
	save_level(AUTOSAVE_PATH)


func _save_now() -> void:
	if _autosave_timer != null:
		_autosave_timer.stop()
	if is_inside_tree():
		save_level(AUTOSAVE_PATH)


# ------------------------------------------------------------------ playtest

func start_playtest() -> void:
	if _playing:
		return
	_save_now()
	_playing = true
	_painting = false
	_panning = false
	_toolbar.visible = false
	_palette.visible = false
	_hint_panel.visible = false
	_play_bar.visible = true
	_overlay.visible = false
	_rebuild_enemy_nodes()
	for child in _entities.get_children():
		child.process_mode = Node.PROCESS_MODE_INHERIT
	_spawn_preview_mole()
	_create_pit()
	_overlay.queue_redraw()


func stop_playtest() -> void:
	if not _playing:
		return
	_playing = false
	_clear_pit()
	_clear_preview_mole()
	Engine.time_scale = 1.0
	# A playtest is a preview: digging, broken tiles and enemies that wandered
	# off are all rolled back to what the author actually placed.
	_apply_level()
	_toolbar.visible = true
	_palette.visible = true
	_hint_panel.visible = true
	_play_bar.visible = false
	_overlay.visible = true
	_editor_camera.make_current()
	_overlay.queue_redraw()
	_save_now()


func _spawn_preview_mole() -> void:
	_clear_preview_mole()
	_children_before = get_children()
	var mole := MOLE_SCENE.instantiate()
	mole.name = "PreviewMole"
	mole.scale = MOLE_SCALE
	mole.position = _spawn_point
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.scale = MOLE_CAMERA_SCALE
	camera.zoom = MOLE_CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	mole.add_child(camera)
	add_child(mole)
	mole.global_position = _spawn_point
	_mole = mole
	_mole_camera = camera
	camera.make_current()


func _clear_preview_mole() -> void:
	if is_instance_valid(_mole):
		remove_child(_mole)
		_mole.queue_free()
	_mole = null
	_mole_camera = null
	_free_preview_orphans()


## Frees the world-space nodes the mole parented above itself inside this scene
## (swing ghosts, the dig cursor, stray projectiles). Everything the editor owns
## -- the TileMap, palettes, camera, HUD -- was there before the playtest and is
## left alone.
func _free_preview_orphans() -> void:
	if _children_before.is_empty():
		return
	for child in get_children():
		if _children_before.has(child):
			continue
		remove_child(child)
		child.queue_free()
	_children_before = []


func _create_pit() -> void:
	_clear_pit()
	var used := _tilemap.get_used_rect()
	var bottom := float(used.position.y + used.size.y) * _tile_world + _tile_world * 3.0
	var pit := Area2D.new()
	pit.name = "PlaytestPit"
	pit.collision_layer = 0
	pit.collision_mask = 1
	pit.monitoring = true
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24000.0, 240.0)
	shape.shape = box
	pit.add_child(shape)
	pit.position = Vector2(_spawn_point.x, bottom)
	pit.body_entered.connect(_on_pit_body_entered)
	add_child(pit)
	_pit = pit


func _clear_pit() -> void:
	if is_instance_valid(_pit):
		remove_child(_pit)
		_pit.queue_free()
	_pit = null


func _on_pit_body_entered(body: Node) -> void:
	# A playtest should not hand out game overs for a hole in the floor, so the
	# mole is simply put back on the start marker.
	if _playing and body == _mole and body is CharacterBody2D:
		body.global_position = _spawn_point
		body.velocity = Vector2.ZERO


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if _playing:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				stop_playtest()
			elif event.keycode == KEY_F5:
				stop_playtest()
				start_playtest()
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _panning and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_editor_camera.position -= event.relative / _editor_camera.zoom
			_overlay.queue_redraw()
		_update_hover()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.physical_keycode == KEY_Z and event.shift_pressed:
			_redo_last()
		elif event.ctrl_pressed and event.physical_keycode == KEY_Z:
			_undo_last()
		elif event.ctrl_pressed and event.physical_keycode == KEY_Y:
			_redo_last()
		elif event.keycode == KEY_G:
			_show_grid = not _show_grid
			_grid_btn.button_pressed = _show_grid
			_overlay.queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_editor_camera.zoom = Vector2(
			minf(_editor_camera.zoom.x * 1.12, MAX_ZOOM),
			minf(_editor_camera.zoom.y * 1.12, MAX_ZOOM))
		_overlay.queue_redraw()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_editor_camera.zoom = Vector2(
			maxf(_editor_camera.zoom.x / 1.12, MIN_ZOOM),
			maxf(_editor_camera.zoom.y / 1.12, MIN_ZOOM))
		_overlay.queue_redraw()
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_hover_cell = _cell_at_mouse()
			if _load_overlay.visible:
				return
			_push_undo()
			_painting = true
			_last_paint_cell = _hover_cell
			_paint(_hover_cell)
		else:
			if _painting:
				_save_now()
			_painting = false
	elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _load_overlay.visible:
			return
		_push_undo()
		_erase_cell(_cell_at_mouse())
		_mark_dirty()


func _update_hover() -> void:
	var cell := _cell_at_mouse()
	if cell != _hover_cell:
		_hover_cell = cell
		_overlay.queue_redraw()


func _text_focused() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _process(delta: float) -> void:
	if _playing or _panning or _load_overlay.visible or _text_focused():
		return
	var axis := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if axis != Vector2.ZERO:
		_editor_camera.position += axis.normalized() * PAN_SPEED * delta / maxf(_editor_camera.zoom.x, 0.05)
		_overlay.queue_redraw()
	if _painting and (_tool == TOOL_BLOCK or _tool == TOOL_ERASE):
		var cell := _cell_at_mouse()
		if cell != _last_paint_cell:
			_last_paint_cell = cell
			_paint(cell)


# ------------------------------------------------------------------ overlay

func draw_editor_overlay(canvas: CanvasItem) -> void:
	if _playing:
		return
	var view := _visible_world_rect()
	if _show_grid:
		var line_color := Color(1.0, 0.9, 0.65, 0.3)
		var x := floorf(view.position.x / _tile_world) * _tile_world
		var guard := 0
		while x <= view.end.x and guard < 600:
			canvas.draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), line_color, 2.0)
			x += _tile_world
			guard += 1
		var y := floorf(view.position.y / _tile_world) * _tile_world
		guard = 0
		while y <= view.end.y and guard < 600:
			canvas.draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), line_color, 2.0)
			y += _tile_world
			guard += 1

	_draw_spawn_marker(canvas)

	if _hover_cell.x < 900000:
		var center := _cell_center(_hover_cell)
		var half := _tile_world * 0.5
		var rect := Rect2(center - Vector2(half, half), Vector2(_tile_world, _tile_world))
		canvas.draw_rect(rect, Color(1.0, 0.9, 0.6, 0.14), true)
		canvas.draw_rect(rect, Color(1.0, 0.9, 0.6, 0.85), false, 2.0)


func _draw_spawn_marker(canvas: CanvasItem) -> void:
	var spawn := _spawn_point
	var green := Color(0.5, 1.0, 0.58, 1.0)
	canvas.draw_circle(spawn, 9.0, Color(0.4, 1.0, 0.5, 0.3))
	canvas.draw_arc(spawn, 9.0, 0.0, TAU, 24, green, 2.0)
	canvas.draw_line(spawn + Vector2(0.0, -9.0), spawn + Vector2(0.0, -36.0), green, 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([
		spawn + Vector2(0.0, -36.0),
		spawn + Vector2(18.0, -29.0),
		spawn + Vector2(0.0, -22.0),
	]), Color(0.55, 1.0, 0.6, 0.95))


func _visible_world_rect() -> Rect2:
	var viewport := get_viewport_rect().size
	var zoom := _editor_camera.zoom
	var center := _editor_camera.get_screen_center_position()
	var half := Vector2(
		viewport.x / maxf(zoom.x, 0.01) * 0.5,
		viewport.y / maxf(zoom.y, 0.01) * 0.5)
	return Rect2(center - half, half * 2.0)


# ----------------------------------------------------------------------- UI

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.name = "EditorUI"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_ui_root)

	_build_toolbar()
	_build_play_bar()
	_build_palette()
	_build_hint()
	_build_load_overlay()


func _build_toolbar() -> void:
	_toolbar = _make_panel()
	_toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toolbar.offset_left = 12.0
	_toolbar.offset_top = 10.0
	_toolbar.offset_right = -12.0
	_toolbar.offset_bottom = 70.0
	_ui_root.add_child(_toolbar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_toolbar.add_child(row)

	var title := Label.new()
	title.text = "LEVEL EDITOR"
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 5)
	row.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Level name"
	_name_edit.custom_minimum_size = Vector2(210.0, 40.0)
	_name_edit.max_length = 40
	_name_edit.add_theme_font_override("font", UI_FONT)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.add_theme_color_override("font_color", TEXT_COLOR)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(0.78, 0.7, 0.6, 0.85))
	_name_edit.add_theme_color_override("caret_color", ACCENT)
	_name_edit.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER, 4))
	_name_edit.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT, 4))
	_name_edit.text_changed.connect(_on_name_changed)
	row.add_child(_name_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var play_btn := _make_button("PLAY  (F5)", Vector2(120.0, 40.0))
	play_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	play_btn.pressed.connect(start_playtest)
	row.add_child(play_btn)

	var save_btn := _make_button("SAVE", Vector2(84.0, 40.0))
	save_btn.pressed.connect(_on_save_pressed)
	row.add_child(save_btn)

	var load_btn := _make_button("LOAD", Vector2(84.0, 40.0))
	load_btn.pressed.connect(_open_load_overlay)
	row.add_child(load_btn)

	var new_btn := _make_button("NEW", Vector2(78.0, 40.0))
	new_btn.pressed.connect(_on_new_pressed)
	row.add_child(new_btn)

	var exit_btn := _make_button("EXIT", Vector2(78.0, 40.0))
	exit_btn.pressed.connect(_on_exit_pressed)
	row.add_child(exit_btn)


func _build_play_bar() -> void:
	_play_bar = _make_panel()
	_play_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_play_bar.offset_left = 12.0
	_play_bar.offset_top = 10.0
	_play_bar.offset_right = -12.0
	_play_bar.offset_bottom = 70.0
	_play_bar.visible = false
	_ui_root.add_child(_play_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_play_bar.add_child(row)

	var label := Label.new()
	label.text = "PLAYTESTING"
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	row.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var restart_btn := _make_button("RESTART  (F5)", Vector2(150.0, 40.0))
	restart_btn.pressed.connect(_on_restart_pressed)
	row.add_child(restart_btn)

	var edit_btn := _make_button("BACK TO EDITING  (ESC)", Vector2(230.0, 40.0))
	edit_btn.pressed.connect(stop_playtest)
	row.add_child(edit_btn)


func _build_palette() -> void:
	_palette = _make_panel()
	_palette.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_palette.offset_left = 12.0
	_palette.offset_top = 82.0
	_palette.offset_right = 314.0
	_palette.offset_bottom = -96.0
	_ui_root.add_child(_palette)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_palette.add_child(column)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)

	_blocks_tab = _make_button("BLOCKS", Vector2(136.0, 40.0))
	_blocks_tab.toggle_mode = true
	_blocks_tab.pressed.connect(_set_tab.bind(TAB_BLOCKS))
	tabs.add_child(_blocks_tab)

	_enemies_tab = _make_button("ENEMIES", Vector2(136.0, 40.0))
	_enemies_tab.toggle_mode = true
	_enemies_tab.pressed.connect(_set_tab.bind(TAB_ENEMIES))
	tabs.add_child(_enemies_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_block_grid = GridContainer.new()
	_block_grid.columns = 4
	_block_grid.add_theme_constant_override("h_separation", 6)
	_block_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_block_grid)

	_enemy_grid = GridContainer.new()
	_enemy_grid.columns = 2
	_enemy_grid.add_theme_constant_override("h_separation", 6)
	_enemy_grid.add_theme_constant_override("v_separation", 6)
	_enemy_grid.visible = false
	scroll.add_child(_enemy_grid)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)

	_erase_btn = _make_button("ERASE", Vector2(88.0, 38.0))
	_erase_btn.toggle_mode = true
	_erase_btn.tooltip_text = "Remove blocks and enemies (right click also erases)"
	_erase_btn.pressed.connect(_select_tool.bind(TOOL_ERASE))
	tools.add_child(_erase_btn)

	_spawn_btn = _make_button("SPAWN", Vector2(88.0, 38.0))
	_spawn_btn.toggle_mode = true
	_spawn_btn.tooltip_text = "Move the start marker where the mole appears"
	_spawn_btn.pressed.connect(_select_tool.bind(TOOL_SPAWN))
	tools.add_child(_spawn_btn)

	_grid_btn = _make_button("GRID", Vector2(88.0, 38.0))
	_grid_btn.toggle_mode = true
	_grid_btn.button_pressed = true
	_grid_btn.toggled.connect(func(on: bool) -> void:
		_show_grid = on
		_overlay.queue_redraw()
	)
	tools.add_child(_grid_btn)


func _build_hint() -> void:
	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12.0
	panel.offset_top = -46.0
	panel.offset_right = -12.0
	panel.offset_bottom = -10.0
	_ui_root.add_child(panel)
	_hint_panel = panel

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	_hint = Label.new()
	_hint.text = "LMB paint   RMB erase   MMB drag / WASD pan   Wheel zoom   Ctrl+Z undo   G grid"
	_hint.add_theme_font_override("font", UI_FONT)
	_hint.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", Color(0.92, 0.86, 0.76))
	row.add_child(_hint)

	_toast_label = Label.new()
	_toast_label.modulate.a = 0.0
	_toast_label.add_theme_font_override("font", UI_FONT)
	_toast_label.add_theme_font_size_override("font_size", 19)
	_toast_label.add_theme_color_override("font_color", ACCENT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_toast_label)


func _build_load_overlay() -> void:
	_load_overlay = Control.new()
	_load_overlay.name = "LoadOverlay"
	_load_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_overlay.visible = false
	_ui_root.add_child(_load_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.add_child(dim)

	var panel := _make_panel()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_top = -220.0
	panel.offset_right = 220.0
	panel.offset_bottom = 220.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "LOAD LEVEL"
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_load_list)

	var close_btn := _make_button("CLOSE", Vector2(140.0, 40.0))
	close_btn.pressed.connect(_close_load_overlay)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close_btn)
	column.add_child(close_row)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, PANEL_BORDER, 4))
	return panel


func _make_button(label: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = min_size
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.5))
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", _style(BUTTON_HOVER, ACCENT))
	button.add_theme_stylebox_override("pressed", _style(BUTTON_PRESSED, ACCENT))
	button.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT))
	button.add_theme_stylebox_override("disabled", _style(BUTTON_DISABLED, Color(0.3, 0.24, 0.2)))
	return button


func _style(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


# ------------------------------------------------------------- palette setup

func _setup_palette() -> void:
	var tileset := _tilemap.tile_set
	var source := tileset.get_source(TERRAIN_SOURCE) as TileSetAtlasSource
	if source != null and source.texture != null:
		var tile_px := Vector2(tileset.tile_size)
		var first := true
		for i in source.get_tiles_count():
			var coords := source.get_tile_id(i)
			var data := source.get_tile_data(coords, 0)
			if data == null or data.get_collision_polygons_count(0) <= 0:
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = source.texture
			atlas.region = Rect2(Vector2(coords) * tile_px, tile_px)
			var button := Button.new()
			button.icon = atlas
			button.expand_icon = true
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(60.0, 60.0)
			button.tooltip_text = "Block %d, %d" % [coords.x, coords.y]
			button.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER, 4))
			button.add_theme_stylebox_override("hover", _style(BUTTON_HOVER, ACCENT, 4))
			button.add_theme_stylebox_override("pressed", _style(BUTTON_PRESSED, ACCENT, 4))
			button.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT, 4))
			button.pressed.connect(_on_block_selected.bind(coords))
			_block_grid.add_child(button)
			_block_buttons[coords] = button
			if first:
				_selected_block = coords
				first = false

	for i in ENEMY_CATALOG.size():
		var spec: Dictionary = ENEMY_CATALOG[i]
		var button := Button.new()
		button.text = str(spec["name"])
		button.icon = _enemy_icon(str(spec["name"]))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(136.0, 52.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", TEXT_COLOR)
		button.add_theme_constant_override("icon_max_width", 40)
		button.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER, 4))
		button.add_theme_stylebox_override("hover", _style(BUTTON_HOVER, ACCENT, 4))
		button.add_theme_stylebox_override("pressed", _style(BUTTON_PRESSED, ACCENT, 4))
		button.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT, 4))
		button.pressed.connect(_on_enemy_selected.bind(i))
		_enemy_grid.add_child(button)
		_enemy_buttons.append(button)


func _enemy_icon(enemy_name: String) -> Texture2D:
	var node := _make_enemy_node(enemy_name)
	if node == null:
		return null
	var texture := _sprite_preview_texture(node)
	node.free()
	return texture


## First usable frame of whatever visual an enemy scene carries. Animated
## enemies hand back their idle/walk frame; a handful of the simpler ones (bat,
## slime, snake, worm, mushroom) are a single Sprite2D whose flipbook is driven
## by an AnimationPlayer, so the sheet is cut down to its first frame instead.
func _sprite_preview_texture(node: Node) -> Texture2D:
	var animated := _find_animated_sprite(node)
	if animated != null and animated.sprite_frames != null:
		var animations := animated.sprite_frames.get_animation_names()
		if animations.size() > 0:
			var animation := String(animations[0])
			for preferred in ["idle", "walk", "fly", "move", "run"]:
				if animated.sprite_frames.has_animation(preferred):
					animation = preferred
					break
			if animated.sprite_frames.get_frame_count(animation) > 0:
				var frame := animated.sprite_frames.get_frame_texture(animation, 0)
				if frame != null:
					return frame
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			return _sprite_sheet_frame(sprite)
	for child in node.get_children():
		var found := _sprite_preview_texture(child)
		if found != null:
			return found
	return null


func _sprite_sheet_frame(sprite: Sprite2D) -> Texture2D:
	var columns := maxi(sprite.hframes, 1)
	var rows := maxi(sprite.vframes, 1)
	if columns * rows <= 1:
		return sprite.texture
	var frame_size := sprite.texture.get_size() / Vector2(columns, rows)
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite.texture
	atlas.region = Rect2(
		Vector2(float(sprite.frame % columns), float(int(sprite.frame / columns))) * frame_size,
		frame_size)
	return atlas


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node as AnimatedSprite2D
	for child in node.get_children():
		var found := _find_animated_sprite(child)
		if found != null:
			return found
	return null


func _on_block_selected(coords: Vector2i) -> void:
	_selected_block = coords
	_tool = TOOL_BLOCK
	_refresh_tool_buttons()


func _on_enemy_selected(index: int) -> void:
	_selected_enemy = index
	_tool = TOOL_ENEMY
	_refresh_tool_buttons()


func _select_tool(tool: int) -> void:
	_tool = tool
	_refresh_tool_buttons()


func _set_tab(tab: int) -> void:
	_tab = tab
	_block_grid.visible = tab == TAB_BLOCKS
	_enemy_grid.visible = tab == TAB_ENEMIES
	_tool = TOOL_BLOCK if tab == TAB_BLOCKS else TOOL_ENEMY
	_refresh_tool_buttons()


func _refresh_tool_buttons() -> void:
	_blocks_tab.button_pressed = _tab == TAB_BLOCKS
	_enemies_tab.button_pressed = _tab == TAB_ENEMIES
	_erase_btn.button_pressed = _tool == TOOL_ERASE
	_spawn_btn.button_pressed = _tool == TOOL_SPAWN
	for coords in _block_buttons:
		var button: Button = _block_buttons[coords]
		button.button_pressed = _tool == TOOL_BLOCK and coords == _selected_block
	for i in _enemy_buttons.size():
		var button: Button = _enemy_buttons[i]
		button.button_pressed = _tool == TOOL_ENEMY and i == _selected_enemy


# -------------------------------------------------------------- UI handlers

func _on_name_changed(text: String) -> void:
	_level_name = text
	_mark_dirty()


func _on_save_pressed() -> void:
	_level_name = _name_edit.text.strip_edges()
	if _level_name.is_empty():
		_level_name = DEFAULT_LEVEL_NAME
		_name_edit.text = _level_name
	var path := "%s/%s.json" % [SAVE_DIR, _slug(_level_name)]
	if save_level(path):
		_toast("Saved \"%s\"" % _level_name)
	else:
		_toast("Could not save")
	_mark_dirty()


func _on_new_pressed() -> void:
	_push_undo()
	_new_level(true)
	_toast("New level")
	_mark_dirty()


func _on_restart_pressed() -> void:
	stop_playtest()
	start_playtest()


func _on_exit_pressed() -> void:
	_save_now()
	get_tree().change_scene_to_file("res://scenes/intro.tscn")


func _open_load_overlay() -> void:
	_refresh_load_list()
	_load_overlay.visible = true


func _close_load_overlay() -> void:
	_load_overlay.visible = false


func _refresh_load_list() -> void:
	for child in _load_list.get_children():
		_load_list.remove_child(child)
		child.queue_free()

	var files := DirAccess.get_files_at(SAVE_DIR)
	var entries: Array = []
	for raw_name in files:
		var file_name := str(raw_name)
		if not file_name.ends_with(".json"):
			continue
		if file_name == AUTOSAVE_PATH.get_file():
			continue
		entries.append(file_name)
	entries.sort()

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No saved levels yet."
		empty.add_theme_font_override("font", UI_FONT)
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
		_load_list.add_child(empty)
		return

	for raw_entry in entries:
		var file_name := str(raw_entry)
		var path := "%s/%s" % [SAVE_DIR, file_name]
		var label: String = file_name.get_basename()
		var parsed = _read_json(path)
		if parsed is Dictionary and parsed.has("name"):
			label = str(parsed["name"])
		var button := _make_button(label, Vector2(360.0, 42.0))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_load_file.bind(path))
		_load_list.add_child(button)


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _on_load_file(path: String) -> void:
	_push_undo()
	if load_level(path):
		_editor_camera.position = _spawn_point
		_close_load_overlay()
		_toast("Loaded \"%s\"" % _level_name)
		_mark_dirty()
	else:
		_toast("Could not load that file")


func _toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
	_toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
