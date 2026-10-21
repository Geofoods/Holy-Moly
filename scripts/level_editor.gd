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
## Controls: left click paints, right click erases, and R turns on rectangle
## filling, which paints every cell across a drag as one solid slab instead of a
## line of blocks. The same drag clears a slab with ERASE selected, or with the
## right button. The middle mouse button drags the view (WASD/arrows pan too), the
## wheel zooms, Ctrl+Z undoes and G toggles the grid.
##
## The WORLD panel picks which parallax backdrop the level uses, how hard the
## vignette filter bites, and whether fireflies drift through it, so a level's
## look is authored right alongside its geometry.
##
## The ITEMS tab also carries the bits of a level that are not just things to
## walk into: a Portal, the way out; a Respawn Station, the checkpoint a playtest
## death returns to; and Goblin Gilbert's stall, where the mole can spend its
## coins. A checkpoint is banked in a playtest with the interact key, exactly as
## in the campaign, and never touches the player's real save.

const TOOL_BLOCK := 0
const TOOL_ENEMY := 1
const TOOL_ERASE := 2
const TOOL_SPAWN := 3
const TOOL_CHEST := 4
const TOOL_ITEM := 5
const TOOL_PORTAL := 6
const TOOL_CHECKPOINT := 7
const TOOL_GILBERT := 8

const TAB_BLOCKS := 0
const TAB_ENEMIES := 1
const TAB_ITEMS := 2

const TILE_LAYER := 0
const TERRAIN_SOURCE := 0

const MOLE_SCENE := preload("res://scenes/mole.tscn")
const HEART_SCENE := preload("res://scenes/heart.tscn")
const INVENTORY_UI_SCENE := preload("res://scenes/inventory_ui.tscn")
const CHEST_SCENE := preload("res://chest.tscn")
const DROPPED_ITEM_SCENE := preload("res://scenes/dropped_item.tscn")
const PORTAL_SCENE := preload("res://scenes/level_portal.tscn")
const PORTAL_SCRIPT := preload("res://scripts/level_portal.gd")
const RESPAWN_STATION_SCENE := preload("res://scenes/respawn_station.tscn")
const RESPAWN_STATION_SCRIPT := preload("res://scripts/respawn_station.gd")
const SHOPKEEPER_SCENE := preload("res://scenes/shopkeeper_npc.tscn")
const CHECKPOINT_SHEET := preload("res://sprites/checkpoint.png")
const GILBERT_SHEET := preload("res://sprites/shopt.png")
const CHEST_ICON := preload("res://chest.webp")
const UI_FONT := preload("res://Baby Doll.otf")

## Where EXIT goes: the title screen the editor was opened from.
const TITLE_SCENE := "res://scenes/intro.tscn"

const SAVE_DIR := "user://levels"
const AUTOSAVE_PATH := "user://levels/_autosave.json"
const AUTOSAVE_DELAY := 0.7
const DEFAULT_LEVEL_NAME := "Untitled Level"

## The campaign levels scale the mole down to a quarter so he stands roughly
## one tile tall next to the half-scaled 160px TileSet.
const MOLE_SCALE := Vector2(0.25, 0.25)
const MOLE_CAMERA_SCALE := Vector2(4.0, 4.0)
const MOLE_CAMERA_ZOOM := Vector2(0.65, 0.65)

## The campaign levels hand-place the heart HUD at this scale; its own script
## then shrinks it by a further 0.75 and parks it in the bottom-left corner.
const HEART_SCALE := Vector2(0.24147864, 0.24147864)

## How long the LEVEL COMPLETE banner is left up before the playtest packs itself
## away. Long enough to read it, short enough not to feel like a wait.
const PORTAL_RETURN_DELAY := 1.3

const PAN_SPEED := 900.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 2.5
const UNDO_LIMIT := 40

const NEW_FLOOR_WIDTH := 12
const NEW_FLOOR_ROW := 2
const DEFAULT_SPAWN_CELL := Vector2i(6, 1)

const ENEMY_CATALOG := [
	{"name": "Ant", "scene": "res://scenes/antenemy.tscn"},
	{"name": "Beetle", "scene": "res://scenes/beetleenemy.tscn"},
	{"name": "Goblin", "scene": "res://scenes/goblinenemy.tscn"},
	{"name": "Hornet", "scene": "res://scenes/hornet_enemy.tscn"},
	{"name": "Slime", "scene": "res://scenes/slimeenemy.tscn"},
]

## What the ITEMS tab offers, in the order it lists them.
##
## The four items are the whole of the merchant's item shelf (see the shop's
## _build_item_catalog): they are ItemData resources, placed as pickups that
## hover where they are put and are collected by walking into them.
##
## Weapons are deliberately absent. They reach the player by purchase or story
## unlock in the campaign, so a level hands out items and leaves the loadout
## alone. A saved level that still carries one of the old weapon rows loads with
## that row dropped, the same as any other value the palette no longer knows.
const ITEM_CATALOG := [
	{"kind": "item", "name": "Drill", "value": "res://resources/drill.tres"},
	{"kind": "item", "name": "Bomb", "value": "res://resources/bomb.tres"},
	{"kind": "item", "name": "Ice Bomb", "value": "res://resources/ice_bomb.tres"},
	{"kind": "item", "name": "Holy Water", "value": "res://resources/holy_water.tres"},
]

## The campaign's three parallax backdrops. Index 0 is the scene's own
## ParallaxBackground, so the extra two are only instantiated when needed.
const BACKGROUND_CATALOG := [
	{"name": "Teal", "scene": "res://scenes/parallax_background.tscn", "tint": Color(0.36, 0.72, 0.82)},
	{"name": "Purple", "scene": "res://scenes/parallax_background2.tscn", "tint": Color(0.94, 0.58, 0.95)},
	{"name": "Red", "scene": "res://scenes/parallax_background3.tscn", "tint": Color(0.98, 0.38, 0.16)},
]

## Matches the 0.55 the campaign levels use, so a fresh level starts out with
## the look the player will actually see.
const DEFAULT_VIGNETTE := 0.55

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
@onready var _background: Node2D = $ParallaxBackground
@onready var _vignette_rect: ColorRect = $VignetteLayer/VignetteRect

## World size of one cell (tile_size * the TileMap's scale).
var _tile_world := 80.0

var _tiles: Dictionary = {}
var _enemies: Array = []
## Chests and placed item pickups, kept apart from enemies because they carry a
## resource path as well as a position.
var _props: Array = []
var _spawn_point := Vector2.ZERO
var _level_name := DEFAULT_LEVEL_NAME
var _background_index := 0
var _vignette := DEFAULT_VIGNETTE
var _fireflies := true

var _tool := TOOL_BLOCK
var _tab := TAB_BLOCKS
var _selected_block := Vector2i.ZERO
var _selected_enemy := 0
var _selected_item := 0
var _show_grid := true

var _hover_cell := Vector2i(999999, 999999)
var _painting := false
var _panning := false
var _last_paint_cell := Vector2i(999999, 999999)

## Rectangle filling: a drag from one corner to the other fills every cell in
## between, which is how floors and walls get laid down without a row of clicks.
var _rect_mode := false
## True between the press that anchors a rectangle and the release that fills or
## clears it, with the button that opened it remembered so the right one ends it.
var _rect_active := false
var _rect_button := MOUSE_BUTTON_LEFT
## Set while the open rectangle is clearing cells rather than painting them.
var _rect_erase := false
var _rect_anchor := Vector2i.ZERO

var _undo_stack: Array = []
var _redo_stack: Array = []

var _playing := false
## Set the moment a portal is stepped into, so a finished run ends once and cannot
## be ended again while the LEVEL COMPLETE banner is still up.
var _finishing := false
var _mole: Node = null
var _mole_camera: Camera2D = null
var _pit: Area2D = null
## The station banked in this playtest, if any. A death puts the mole back on its
## pad (or on the start marker when nothing has been banked yet). Never written
## to Progress: a checkpoint taken while testing is part of the test.
var _checkpoint_station: Node = null
var _heart_layer: CanvasLayer = null
## The campaign's own hotbar, shown only while testing so the author can see
## what the items they placed actually look like when collected.
var _inventory_layer: CanvasLayer = null
## Campaign state borrowed for the playtest: the mole banks its health and the
## level it died in into Inventory on death, so both are snapshotted here and
## put back when the author returns to editing.
var _saved_level_path := ""
var _saved_health := 0.0
## The hotbar's contents are borrowed too: collecting an authored pickup in a
## playtest must not quietly add it to the player's real inventory.
var _saved_slots: Array = []
var _saved_slot_counts: Array = []
var _saved_selected_slot := -1
## The shop's loadout and purse, likewise borrowed: a previewed enemy drops coins,
## which should not follow the author back out of a playtest. See _snapshot_shop().
var _saved_shop: Dictionary = {}
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
var _items_box: VBoxContainer = null
var _item_grid: GridContainer = null
var _blocks_tab: Button = null
var _enemies_tab: Button = null
var _items_tab: Button = null
var _chest_btn: Button = null
var _portal_btn: Button = null
var _checkpoint_btn: Button = null
var _gilbert_btn: Button = null
var _erase_btn: Button = null
var _spawn_btn: Button = null
var _grid_btn: Button = null
var _rect_btn: Button = null
var _world_panel: PanelContainer = null
var _vignette_slider: HSlider = null
var _vignette_value: Label = null
var _firefly_btn: Button = null
var _firefly_spawner: Node2D = null
var _load_overlay: Control = null
var _load_list: VBoxContainer = null
var _online_overlay: Control = null
var _online_publish_view: VBoxContainer = null
var _online_browse_view: VBoxContainer = null
var _online_tab_publish: Button = null
var _online_tab_browse: Button = null
var _publish_author_edit: LineEdit = null
var _publish_description_edit: TextEdit = null
var _publish_status: Label = null
var _publish_button: Button = null
var _browse_status: Label = null
var _browse_list: VBoxContainer = null
var _browse_refresh_button: Button = null
var _browse_request_serial := 0
var _block_buttons: Dictionary = {}
var _enemy_buttons: Array = []
var _item_buttons: Array = []
var _background_buttons: Array = []


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
	_setup_backgrounds()
	_setup_fireflies()

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
	# A preview still running as the scene goes has to hand back what it borrowed.
	# _restore_shop() is the one that matters: the shop refuses to save for the
	# length of a playtest, so leaving with it still on would keep the player's
	# own purchases off disk for the rest of the session.
	if _playing:
		_release_borrowed_state()
	# The mole runs the whole campaign at 1.2x; leaving that set would speed the
	# editor (and the menus) up for the rest of the session.
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- level state

func _new_level(with_floor: bool) -> void:
	_tiles.clear()
	_enemies.clear()
	_props.clear()
	_level_name = DEFAULT_LEVEL_NAME
	if _name_edit != null:
		_name_edit.text = _level_name
	_background_index = 0
	_vignette = DEFAULT_VIGNETTE
	_fireflies = true
	if with_floor:
		for x in NEW_FLOOR_WIDTH:
			_tiles[Vector2i(x, NEW_FLOOR_ROW)] = Vector3i(TERRAIN_SOURCE, 0, 0)
	_apply_level()
	_apply_world()
	_spawn_point = _cell_center(DEFAULT_SPAWN_CELL) + Vector2(0.0, _tile_world * 0.15)
	if _editor_camera != null:
		_editor_camera.position = _spawn_point
	_overlay.queue_redraw()


func _apply_level() -> void:
	_tilemap.clear_layer(TILE_LAYER)
	for cell in _tiles:
		var t: Vector3i = _tiles[cell]
		_tilemap.set_cell(TILE_LAYER, cell, t.x, Vector2i(t.y, t.z))
	_rebuild_entity_nodes()
	_overlay.queue_redraw()


## Rebuilds every placed enemy, chest and item from the authored data, which is
## what rolls a playtest's wandering, opened chests and collected pickups back to
## what the level actually holds.
func _rebuild_entity_nodes() -> void:
	for child in _entities.get_children():
		_entities.remove_child(child)
		child.queue_free()
	for entry in _enemies:
		var node := _make_enemy_node(str(entry["name"]))
		if node == null:
			continue
		_entities.add_child(node)
		node.global_position = entry["position"]
		_freeze_entity(node)
	for prop in _props:
		var node := _make_prop_node(prop)
		if node == null:
			continue
		_entities.add_child(node)
		node.global_position = prop["position"]
		_freeze_entity(node)


## Edit mode has to hold everything still: CharacterBody2D enemies stop taking
## physics steps, and a chest -- a RigidBody2D in the campaign -- is frozen so it
## does not slide off the tile it was dropped on while the author works.
func _freeze_entity(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is RigidBody2D:
		(node as RigidBody2D).freeze = true


func _resume_entity(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is RigidBody2D:
		(node as RigidBody2D).freeze = false


func _make_enemy_node(enemy_name: String) -> Node2D:
	for spec in ENEMY_CATALOG:
		if str(spec["name"]) == enemy_name:
			var packed := load(str(spec["scene"])) as PackedScene
			if packed != null:
				return packed.instantiate() as Node2D
	return null


func _make_prop_node(prop: Dictionary) -> Node2D:
	match str(prop["kind"]):
		"chest":
			# No item exported, exactly like every chest in the campaign: the
			# chest rolls its own loot when it is opened.
			return CHEST_SCENE.instantiate() as Node2D
		"item":
			var item := load(str(prop["value"])) as ItemData
			if item == null:
				return null
			var node = DROPPED_ITEM_SCENE.instantiate()
			node.item_data = item
			# Hover where it was placed instead of arcing out of a chest.
			node.start_floating = true
			return node as Node2D
		"portal":
			var portal = PORTAL_SCENE.instantiate()
			# Wired here rather than when a playtest begins: the nodes are rebuilt
			# for a playtest anyway, so the connection arrives with them. In edit
			# mode the portal is frozen and has no signal to send.
			portal.entered.connect(_on_portal_entered)
			return portal as Node2D
		"checkpoint":
			return RESPAWN_STATION_SCENE.instantiate() as Node2D
		"gilbert":
			return SHOPKEEPER_SCENE.instantiate() as Node2D
	return null


func _is_known_enemy(enemy_name: String) -> bool:
	for spec in ENEMY_CATALOG:
		if str(spec["name"]) == enemy_name:
			return true
	return false


## A prop is only kept if what it holds still exists: an item path that no longer
## resolves is dropped rather than left in the level as an invisible thing that
## cannot be placed again. The same test retires the weapon rows old saves were
## saved with, since the palette no longer offers a weapon.
func _is_known_prop_value(kind: String, value: String) -> bool:
	for spec in ITEM_CATALOG:
		if str(spec["kind"]) != kind:
			continue
		if str(spec["value"]) == value:
			return true
	return false


# ------------------------------------------------------------------ world look

## Index 0 is the backdrop already authored into the scene; the remaining
## backdrops are instantiated once and hidden, so switching is just a visibility
## flip and the editor's child list stays stable across a playtest.
func _setup_backgrounds() -> void:
	for i in range(1, BACKGROUND_CATALOG.size()):
		var packed := load(str(BACKGROUND_CATALOG[i]["scene"])) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node2D
		node.name = "Background%d" % i
		node.visible = false
		add_child(node)
	_apply_world()


## The editor's own firefly swarm follows the camera while the author works and
## the preview mole during a playtest, so the toggle previews exactly what plays.
func _setup_fireflies() -> void:
	var packed := load("res://scenes/firefly_spawner.tscn") as PackedScene
	if packed == null:
		return
	_firefly_spawner = packed.instantiate() as Node2D
	if _firefly_spawner == null:
		return
	_firefly_spawner.name = "FireflySpawner"
	add_child(_firefly_spawner)
	# Keep fireflies below the editor's grid/marker overlay.
	if _overlay != null:
		move_child(_firefly_spawner, _overlay.get_index())
	_apply_fireflies()


func _apply_world() -> void:
	_apply_background()
	_apply_vignette()
	_apply_fireflies()
	_refresh_world_ui()


func _apply_background() -> void:
	_background_index = clampi(_background_index, 0, BACKGROUND_CATALOG.size() - 1)
	for i in BACKGROUND_CATALOG.size():
		var node := _background_for(i)
		if node != null:
			node.visible = i == _background_index


func _background_for(index: int) -> Node2D:
	if index <= 0:
		return _background
	return get_node_or_null("Background%d" % index) as Node2D


func _apply_vignette() -> void:
	var material := _vignette_rect.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("darkness", _vignette)


func _firefly_focus() -> Node2D:
	if _playing and is_instance_valid(_mole):
		return _mole
	return _editor_camera


func _apply_fireflies() -> void:
	if _firefly_spawner == null:
		return
	_firefly_spawner.visible = _fireflies
	_firefly_spawner.process_mode = (
			Node.PROCESS_MODE_INHERIT if _fireflies
			else Node.PROCESS_MODE_DISABLED)
	_firefly_spawner.call("set_focus_override", _firefly_focus())


func _refresh_world_ui() -> void:
	for i in _background_buttons.size():
		var button: Button = _background_buttons[i]
		button.button_pressed = i == _background_index
	if _vignette_slider != null:
		_vignette_slider.set_value_no_signal(_vignette)
	if _vignette_value != null:
		_vignette_value.text = "%d%%" % roundi(_vignette * 100.0)
	if _firefly_btn != null:
		_firefly_btn.button_pressed = _fireflies
		_firefly_btn.text = "Fireflies: ON" if _fireflies else "Fireflies: OFF"


# ------------------------------------------------------------------- painting

func _paint(cell: Vector2i) -> void:
	match _tool:
		TOOL_BLOCK:
			_tiles[cell] = Vector3i(TERRAIN_SOURCE, _selected_block.x, _selected_block.y)
			_tilemap.set_cell(TILE_LAYER, cell, TERRAIN_SOURCE, _selected_block)
		TOOL_ENEMY:
			var spec: Dictionary = ENEMY_CATALOG[_selected_enemy]
			_enemies.append({"name": str(spec["name"]), "position": _enemy_spot(cell)})
			_rebuild_entity_nodes()
		TOOL_CHEST:
			_props.append({"kind": "chest", "value": "", "position": _cell_center(cell)})
			_rebuild_entity_nodes()
		TOOL_PORTAL:
			_props.append({"kind": "portal", "value": "", "position": _cell_center(cell)})
			_rebuild_entity_nodes()
		TOOL_CHECKPOINT:
			_props.append({"kind": "checkpoint", "value": "", "position": _cell_center(cell)})
			_rebuild_entity_nodes()
		TOOL_GILBERT:
			_props.append({"kind": "gilbert", "value": "", "position": _cell_center(cell)})
			_rebuild_entity_nodes()
		TOOL_ITEM:
			var choice: Dictionary = ITEM_CATALOG[_selected_item]
			_props.append({
				"kind": str(choice["kind"]),
				"value": str(choice["value"]),
				"position": _cell_center(cell),
			})
			_rebuild_entity_nodes()
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
		_rebuild_entity_nodes()
		return
	var prop := _prop_index_at(_cell_center(cell))
	if prop >= 0:
		_props.remove_at(prop)
		_rebuild_entity_nodes()
		return
	if _tiles.erase(cell):
		_tilemap.erase_cell(TILE_LAYER, cell)


## Fills every cell between two corners with the selected block.
func _fill_rect(from: Vector2i, to: Vector2i) -> void:
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			var cell := Vector2i(x, y)
			_tiles[cell] = Vector3i(TERRAIN_SOURCE, _selected_block.x, _selected_block.y)
			_tilemap.set_cell(TILE_LAYER, cell, TERRAIN_SOURCE, _selected_block)
	_overlay.queue_redraw()
	_mark_dirty()


## Clears the blocks inside a rectangle. A drag that crossed cells sweeps geometry
## and nothing else: chests, enemies and the rest keep their one-at-a-time erase,
## so carving a hole in a floor cannot also take the contents of the level with
## it. A drag that never moved erases the single thing under the cursor instead,
## exactly the way a plain right click always has.
func _erase_rect(from: Vector2i, to: Vector2i) -> void:
	if from == to:
		_erase_cell(from)
	else:
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
				var cell := Vector2i(x, y)
				if _tiles.erase(cell):
					_tilemap.erase_cell(TILE_LAYER, cell)
	_overlay.queue_redraw()
	_mark_dirty()


## The one place that decides what an open rectangle does when it is let go.
func _commit_rect() -> void:
	if _rect_erase:
		_erase_rect(_rect_anchor, _hover_cell)
	else:
		_fill_rect(_rect_anchor, _hover_cell)
	_rect_active = false
	_save_now()
	_overlay.queue_redraw()


func _prop_index_at(point: Vector2) -> int:
	var radius := _tile_world * 0.7
	for i in range(_props.size() - 1, -1, -1):
		var position: Vector2 = _props[i]["position"]
		if position.distance_to(point) <= radius:
			return i
	return -1


func _enemy_index_at(point: Vector2) -> int:
	var radius := _tile_world * 0.7
	for i in range(_enemies.size() - 1, -1, -1):
		var position: Vector2 = _enemies[i]["position"]
		if position.distance_to(point) <= radius:
			return i
	return -1


func _cell_at_mouse() -> Vector2i:
	return _tilemap.local_to_map(_tilemap.to_local(get_global_mouse_position()))


## Rectangle filling only means something for the two tools that lay down cells
## one at a time. Enemies, chests, items, the portal, the station, the merchant
## and the start marker are single objects, so they are still placed with one
## click in rectangle mode.
func _rect_on() -> bool:
	return _rect_mode and (_tool == TOOL_BLOCK or _tool == TOOL_ERASE)


func _cell_center(cell: Vector2i) -> Vector2:
	return _tilemap.to_global(_tilemap.map_to_local(cell))


func _enemy_spot(cell: Vector2i) -> Vector2:
	return _cell_center(cell) + Vector2(0.0, _tile_world * 0.35)


# -------------------------------------------------------------- undo / redo

func _snapshot() -> Dictionary:
	return {
		"tiles": _tiles.duplicate(true),
		"enemies": _enemies.duplicate(true),
		"props": _props.duplicate(true),
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
	_props = snapshot["props"].duplicate(true)
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
	var props: Array = []
	for entry in _props:
		var position: Vector2 = entry["position"]
		props.append([str(entry["kind"]), str(entry["value"]), position.x, position.y])
	return {
		"version": 3,
		"name": _level_name,
		"spawn": [_spawn_point.x, _spawn_point.y],
		"blocks": blocks,
		"enemies": enemies,
		"props": props,
		"background": _background_index,
		"vignette": _vignette,
		"fireflies": _fireflies,
	}


func from_dict(data: Dictionary) -> bool:
	if not (data.has("blocks") and data.has("enemies")):
		return false
	_tiles.clear()
	_enemies.clear()
	_props.clear()
	for row in data["blocks"]:
		if row is Array and row.size() >= 5:
			var cell := Vector2i(int(row[3]), int(row[4]))
			_tiles[cell] = Vector3i(int(row[0]), int(row[1]), int(row[2]))
	for row in data["enemies"]:
		if row is Array and row.size() >= 3:
			var enemy_name := str(row[0])
			# An enemy that has since been taken out of the editor is dropped
			# rather than kept as an entry that can never be seen or placed.
			if not _is_known_enemy(enemy_name):
				continue
			_enemies.append({
				"name": enemy_name,
				"position": Vector2(float(row[1]), float(row[2])),
			})
	# Absent from anything saved before chests and items existed.
	for row in data.get("props", []):
		if not (row is Array and row.size() >= 4):
			continue
		var kind := str(row[0])
		var value := str(row[1])
		if kind == "chest" or kind == "portal" or kind == "checkpoint" or kind == "gilbert":
			# None of these carries a second value: a chest rolls its own loot, a
			# portal has nowhere in particular to lead, and the station and the
			# stall are the scene themselves.
			value = ""
		elif not _is_known_prop_value(kind, value):
			continue
		_props.append({
			"kind": kind,
			"value": value,
			"position": Vector2(float(row[2]), float(row[3])),
		})
	var spawn = data.get("spawn", null)
	if spawn is Array and spawn.size() >= 2:
		_spawn_point = Vector2(float(spawn[0]), float(spawn[1]))
	else:
		_spawn_point = Vector2.ZERO
	_level_name = str(data.get("name", DEFAULT_LEVEL_NAME))
	if _name_edit != null:
		_name_edit.text = _level_name
	_background_index = clampi(int(data.get("background", 0)), 0, BACKGROUND_CATALOG.size() - 1)
	_vignette = clampf(float(data.get("vignette", DEFAULT_VIGNETTE)), 0.0, 1.0)
	_fireflies = bool(data.get("fireflies", true))
	_apply_level()
	_apply_world()
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
	_close_online_overlay()
	_save_now()
	_playing = true
	_finishing = false
	_painting = false
	_panning = false
	_rect_active = false
	# Every playtest is a fresh run, so its checkpoint starts unbanked.
	_checkpoint_station = null
	_toolbar.visible = false
	_palette.visible = false
	_hint_panel.visible = false
	_world_panel.visible = false
	_play_bar.visible = true
	_overlay.visible = false
	_rebuild_entity_nodes()
	for child in _entities.get_children():
		_resume_entity(child)
		_wire_playtest_checkpoint(child)
	# A playtest is always a fresh run: the mole reads its health out of
	# Inventory, so a previous run left at three hearts would otherwise carry
	# straight over. The banked values go back untouched on stop.
	_saved_level_path = Inventory.current_level_path
	_saved_health = Inventory.player_health
	_saved_slots = Inventory.slots.duplicate()
	_saved_slot_counts = Inventory.slot_counts.duplicate()
	_saved_selected_slot = Inventory.selected_slot
	Inventory.player_health = Inventory.MAX_HEALTH
	_snapshot_shop()
	_create_playtest_hud()
	_spawn_preview_mole()
	_apply_fireflies()
	_create_pit()
	_overlay.queue_redraw()


func stop_playtest() -> void:
	if not _playing:
		return
	_playing = false
	_checkpoint_station = null
	_clear_pit()
	_clear_playtest_hud()
	_clear_preview_mole()
	_apply_fireflies()
	_release_borrowed_state()
	# A playtest is a preview: digging, broken tiles and enemies that wandered
	# off are all rolled back to what the author actually placed.
	_apply_level()
	_toolbar.visible = true
	_palette.visible = true
	_hint_panel.visible = true
	_world_panel.visible = true
	_play_bar.visible = false
	_overlay.visible = true
	_editor_camera.make_current()
	_overlay.queue_redraw()
	_save_now()


## Hands back everything a playtest borrowed: the mole's health and the level it
## would have banked a death in, and the shop's loadout and purse. Called when a
## playtest stops, and again if the scene is left with one still running.
func _release_borrowed_state() -> void:
	Inventory.current_level_path = _saved_level_path
	Inventory.player_health = _saved_health
	if not _saved_slots.is_empty():
		Inventory.slots = _saved_slots.duplicate()
		Inventory.slot_counts = _saved_slot_counts.duplicate()
		_saved_slots = []
		_saved_slot_counts = []
		if Inventory.selected_slot != _saved_selected_slot:
			Inventory.selected_slot = _saved_selected_slot
	_restore_shop()
	Engine.time_scale = 1.0


## The shop's loadout and purse are borrowed for the playtest the same way the
## mole's health is. Coins a previewed enemy drops would otherwise be banked into
## the player's real save.
func _snapshot_shop() -> void:
	_saved_shop = {
		"owned": Shop.owned.duplicate(),
		"melee": Shop.equipped_melee_id,
		"ranged": Shop.equipped_ranged_id,
		"ranged_active": Shop.ranged_active,
		"coins": Shop.coins,
	}
	# Held for the whole playtest so nothing mid-run rewrites the save file
	# either; the values above put the in-memory state back on the way out.
	Shop.suppress_save = true


func _restore_shop() -> void:
	if _saved_shop.is_empty():
		return
	Shop.owned = _saved_shop["owned"]
	Shop.equipped_melee_id = str(_saved_shop["melee"])
	Shop.equipped_ranged_id = str(_saved_shop["ranged"])
	Shop.ranged_active = bool(_saved_shop["ranged_active"])
	Shop.coins = int(_saved_shop["coins"])
	Shop.suppress_save = false
	# The coin HUD is permanent, so it has to be told the purse went back. The
	# loadout signal deliberately stays quiet: the preview mole has already been
	# detached by now, and its sword is the only listener an editor run has.
	Shop.coins_changed.emit(Shop.coins)
	_saved_shop = {}


func _spawn_preview_mole() -> void:
	_clear_preview_mole()
	_children_before = get_children()
	var mole := MOLE_SCENE.instantiate()
	mole.name = "PreviewMole"
	mole.scale = MOLE_SCALE
	mole.position = _spawn_point
	# Deaths stay in the editor: the mole reports the death and is put back on
	# its feet at the checkpoint instead of handing off to the game over screen.
	mole.playtest = true
	mole.died.connect(_on_playtest_mole_died)
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


## The campaign's bottom-left heart plus its HP bar, and the hotbar along the
## bottom edge. Both read Inventory each frame, so they track the borrowed mole
## for free. The heart hangs off a CanvasLayer named "CanvasLayer" with a
## "heart" child because that is exactly the path the mole's health setter looks
## up to play its damage animation.
func _create_playtest_hud() -> void:
	_clear_playtest_hud()
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	layer.layer = 99
	add_child(layer)
	var heart := HEART_SCENE.instantiate() as Node2D
	heart.name = "heart"
	heart.scale = HEART_SCALE
	layer.add_child(heart)
	_heart_layer = layer
	var inventory := INVENTORY_UI_SCENE.instantiate() as CanvasLayer
	inventory.name = "InventoryUI"
	add_child(inventory)
	_inventory_layer = inventory


func _clear_playtest_hud() -> void:
	if is_instance_valid(_heart_layer):
		remove_child(_heart_layer)
		_heart_layer.queue_free()
	_heart_layer = null
	if is_instance_valid(_inventory_layer):
		remove_child(_inventory_layer)
		_inventory_layer.queue_free()
	_inventory_layer = null


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
	# mole is put back at its last checkpoint, or on the start marker if it has
	# not banked one.
	if _playing and body == _mole and body is CharacterBody2D:
		_send_mole_to_checkpoint()


## A station in the level being tested records its checkpoint in this run rather
## than in Progress, so testing a level can never move the player's real
## checkpoint. The pad itself still lights up, prompts, and plays its arrival.
func _wire_playtest_checkpoint(node: Node) -> void:
	if not node.is_in_group("respawn_station") or not node.has_signal("banked"):
		return
	node.set("use_progress", false)
	node.connect("banked", _on_checkpoint_banked)


func _on_checkpoint_banked(station: Node) -> void:
	_checkpoint_station = station


## Where a death puts the mole back: the pad of the checkpoint banked in this
## run, or the start marker when nothing has been banked yet.
func _respawn_point() -> Vector2:
	if is_instance_valid(_checkpoint_station):
		var point: Vector2 = _checkpoint_station.call("spawn_point")
		return point
	return _spawn_point


## A playtest death never leaves for the game over screen. The mole is revived
## where its checkpoint says, with the pad's own materialise when there is one.
func _on_playtest_mole_died() -> void:
	if not _playing or not is_instance_valid(_mole):
		return
	var at_checkpoint := is_instance_valid(_checkpoint_station)
	_mole.call("revive_at", _respawn_point())
	if at_checkpoint:
		_checkpoint_station.call("spawn_mole_in", _mole)
	_show_playtest_banner(
		"BACK AT THE CHECKPOINT" if at_checkpoint else "BACK AT THE START",
		RESPAWN_STATION_SCRIPT.PROMPT_COLOR_ACTIVE, 1.0)


## Puts a living mole back where a death would, which is what falling into the
## playtest pit does: the pad plays its arrival, the start marker just takes it.
func _send_mole_to_checkpoint() -> void:
	if is_instance_valid(_checkpoint_station):
		_checkpoint_station.call("spawn_mole_in", _mole)
		return
	if _mole is CharacterBody2D:
		(_mole as CharacterBody2D).global_position = _spawn_point
		(_mole as CharacterBody2D).velocity = Vector2.ZERO


## The mole walked into the level's portal, so the level is finished. A playtest
## has nowhere to go next, so the run ends the way BACK TO EDITING ends it, with
## the author told why.
func _on_portal_entered() -> void:
	if not _playing or _finishing:
		return
	_finishing = true
	SFX.play_ui("item_pickup", -3.0, 1.5)
	# The mole is stopped where it stands. The banner is a beat to read before the
	# level rolls back, and a run that carried on could still be killed out of it,
	# which would take the editor to the game over screen with it.
	if is_instance_valid(_mole):
		_mole.process_mode = Node.PROCESS_MODE_DISABLED
	_show_completion_banner()
	await get_tree().create_timer(PORTAL_RETURN_DELAY).timeout
	if not _playing:
		return
	stop_playtest()
	_toast("Level complete!")


## An announcement for the moment a level is finished, hung on the same layer as
## the borrowed heart so it stays put while the mole is stopped. It goes away with
## the rest of the playtest HUD, and the editor's own toast takes over after that.
func _show_completion_banner() -> void:
	# The colour of the thing that was walked into, so the two read as one moment.
	_show_playtest_banner("LEVEL COMPLETE!", PORTAL_SCRIPT.RIM, -1.0)


## A line across the top of the playtest HUD. `hold` is how long it stays up
## after fading in; a negative hold leaves it there until the run's HUD is torn
## down, which is what the completion banner wants.
func _show_playtest_banner(text: String, colour: Color, hold: float) -> void:
	if not is_instance_valid(_heart_layer):
		return
	var label := Label.new()
	label.name = "PlaytestBanner"
	label.text = text
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -420.0
	label.offset_top = 140.0
	label.offset_right = 420.0
	label.offset_bottom = 220.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	_heart_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.18)
	if hold < 0.0:
		return
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)


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

	# The online panel owns input while it is open. The dimmer already stops
	# mouse clicks, but this also keeps WASD, undo and the editor shortcuts from
	# firing behind a text field.
	if _online_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			_close_online_overlay()
			get_viewport().set_input_as_handled()
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
		elif event.keycode == KEY_R:
			_rect_btn.button_pressed = not _rect_btn.button_pressed


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Reaching here means the click landed in the world rather than on the UI, so
	# the keyboard belongs to the editor again. Without this the vignette slider
	# keeps focus after it has been dragged, and a focused slider swallows every
	# pan key until something else is clicked.
	get_viewport().gui_release_focus()
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
			if _rect_on():
				# Nothing is painted yet: the anchor is the first corner, and
				# releasing on the same cell is an ordinary one-block click.
				_rect_anchor = _hover_cell
				_rect_button = MOUSE_BUTTON_LEFT
				_rect_erase = _tool == TOOL_ERASE
				_rect_active = true
				_overlay.queue_redraw()
			else:
				_painting = true
				_last_paint_cell = _hover_cell
				_paint(_hover_cell)
		else:
			if _rect_active and _rect_button == MOUSE_BUTTON_LEFT:
				_commit_rect()
			if _painting:
				_save_now()
			_painting = false
			_overlay.queue_redraw()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if _load_overlay.visible:
				return
			_push_undo()
			if _rect_mode:
				# The right button is the erasing hand, so with rectangle filling
				# on it sweeps blocks away whatever tool happens to be selected --
				# that is the gesture a hole gets carved with. A drag that never
				# moves still erases the single thing under the cursor, chests and
				# enemies included.
				_hover_cell = _cell_at_mouse()
				_rect_anchor = _hover_cell
				_rect_button = MOUSE_BUTTON_RIGHT
				_rect_erase = true
				_rect_active = true
				_overlay.queue_redraw()
			else:
				_erase_cell(_cell_at_mouse())
				_mark_dirty()
		elif _rect_active and _rect_button == MOUSE_BUTTON_RIGHT:
			_commit_rect()


func _update_hover() -> void:
	var cell := _cell_at_mouse()
	if cell != _hover_cell:
		_hover_cell = cell
		_overlay.queue_redraw()


## True while the keyboard belongs to a text field or the vignette slider: the
## arrow keys move a slider, and a level named "mushroom" would otherwise drag the
## view around while it is being typed.
func _ui_holds_pan_keys() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is Slider


## The arrow keys come from the built-in ui_* actions; WASD is read straight off
## the physical keys. Going through the actions for WASD does not work: the mole
## binds W to ui_accept (jump) and A/D to ui_left/ui_right, and never binds S at
## all, which leaves the vertical axis with no keys and makes even horizontal
## panning depend on whether a mole has been in the tree yet this session.
func _pan_axis() -> Vector2:
	var axis := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A):
		axis.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		axis.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		axis.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		axis.y += 1.0
	# A/D also arrive through ui_left/ui_right once a mole has run, so a key can be
	# counted twice; only the direction of the axis matters.
	return Vector2(clampf(axis.x, -1.0, 1.0), clampf(axis.y, -1.0, 1.0))


func _process(delta: float) -> void:
	# A release that lands on the UI is swallowed by it and never reaches
	# _unhandled_input, so a drag that ends over the palette would otherwise leave
	# its preview hanging on screen for good.
	if _rect_active and not Input.is_mouse_button_pressed(_rect_button):
		_commit_rect()
	if _playing or _panning or _load_overlay.visible \
			or _online_overlay.visible or _ui_holds_pan_keys():
		return
	var axis := _pan_axis()
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

	if _rect_active and _hover_cell.x < 900000:
		# The rectangle that the release will paint or clear, so the drag shows its
		# size before it commits. Red while erasing, the same warm tone as the hover
		# cell while filling.
		var corner_a := _cell_center(_rect_anchor)
		var corner_b := _cell_center(_hover_cell)
		var half := _tile_world * 0.5
		var rect := Rect2(
			Vector2(minf(corner_a.x, corner_b.x), minf(corner_a.y, corner_b.y)) - Vector2(half, half),
			Vector2(absf(corner_a.x - corner_b.x), absf(corner_a.y - corner_b.y)) + Vector2(_tile_world, _tile_world))
		var tint := Color(1.0, 0.55, 0.5) if _rect_erase else Color(1.0, 0.9, 0.6)
		canvas.draw_rect(rect, Color(tint, 0.13), true)
		canvas.draw_rect(rect, Color(tint, 0.9), false, 3.0)

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
	_build_world_panel()
	_build_hint()
	_build_load_overlay()
	_build_online_overlay()


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
	_name_edit.custom_minimum_size = Vector2(190.0, 40.0)
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

	var online_btn := _make_button("ONLINE", Vector2(88.0, 40.0))
	online_btn.pressed.connect(_open_online_overlay)
	row.add_child(online_btn)

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

	_blocks_tab = _make_button("BLOCKS", Vector2(86.0, 40.0))
	_blocks_tab.toggle_mode = true
	_blocks_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks_tab.pressed.connect(_set_tab.bind(TAB_BLOCKS))
	tabs.add_child(_blocks_tab)

	_enemies_tab = _make_button("ENEMIES", Vector2(86.0, 40.0))
	_enemies_tab.toggle_mode = true
	_enemies_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemies_tab.pressed.connect(_set_tab.bind(TAB_ENEMIES))
	tabs.add_child(_enemies_tab)

	_items_tab = _make_button("ITEMS", Vector2(86.0, 40.0))
	_items_tab.toggle_mode = true
	_items_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_tab.pressed.connect(_set_tab.bind(TAB_ITEMS))
	tabs.add_child(_items_tab)

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

	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 6)
	_items_box.visible = false
	scroll.add_child(_items_box)

	# First in the tab, because a level needs a way out before it needs anything to
	# put in it, and a single row at the top is always in view without scrolling.
	_items_box.add_child(_heading_label("PORTAL"))

	_portal_btn = _make_button("Portal", Vector2(136.0, 52.0))
	_portal_btn.toggle_mode = true
	_portal_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_portal_btn.icon = PORTAL_SCRIPT.icon(40)
	_portal_btn.tooltip_text = "Marks the way out: step into it in a playtest to finish the level"
	_portal_btn.add_theme_constant_override("icon_max_width", 40)
	_portal_btn.pressed.connect(_on_portal_selected)
	_items_box.add_child(_portal_btn)

	_items_box.add_child(_heading_label("CHESTS"))

	_chest_btn = _make_button("Chest", Vector2(136.0, 52.0))
	_chest_btn.toggle_mode = true
	_chest_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_chest_btn.icon = CHEST_ICON
	_chest_btn.tooltip_text = "A chest with random loot, like the ones in the campaign"
	_chest_btn.add_theme_constant_override("icon_max_width", 40)
	_chest_btn.pressed.connect(_on_chest_selected)
	_items_box.add_child(_chest_btn)

	_items_box.add_child(_heading_label("CHECKPOINT"))

	# Straight after the chests, because a level that can kill the player wants a
	# place to come back to before it needs anything else.
	_checkpoint_btn = _make_button("Respawn Station", Vector2(136.0 * 2.0 + 6.0, 52.0))
	_checkpoint_btn.toggle_mode = true
	_checkpoint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checkpoint_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_checkpoint_btn.icon = _square_frame(CHECKPOINT_SHEET, 0)
	_checkpoint_btn.tooltip_text = "Press E next to it in a playtest to bank it; dying then puts the mole back on its pad"
	_checkpoint_btn.add_theme_constant_override("icon_max_width", 40)
	_checkpoint_btn.pressed.connect(_on_checkpoint_selected)
	_items_box.add_child(_checkpoint_btn)

	_items_box.add_child(_heading_label("NPCS"))

	_gilbert_btn = _make_button("Goblin Gilbert", Vector2(136.0 * 2.0 + 6.0, 52.0))
	_gilbert_btn.toggle_mode = true
	_gilbert_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gilbert_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_gilbert_btn.icon = _square_frame(GILBERT_SHEET, 0)
	_gilbert_btn.tooltip_text = "Gilbert's stall: press E in a playtest to browse his stock"
	_gilbert_btn.add_theme_constant_override("icon_max_width", 40)
	_gilbert_btn.pressed.connect(_on_gilbert_selected)
	_items_box.add_child(_gilbert_btn)

	_items_box.add_child(_heading_label("ITEMS"))

	_item_grid = GridContainer.new()
	_item_grid.columns = 1
	_item_grid.add_theme_constant_override("h_separation", 6)
	_item_grid.add_theme_constant_override("v_separation", 6)
	_items_box.add_child(_item_grid)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)

	_erase_btn = _make_button("ERASE", Vector2(88.0, 38.0))
	_erase_btn.toggle_mode = true
	_erase_btn.tooltip_text = "Remove anything placed in the level (right click also erases)"
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

	# The tool row is already full at three buttons, and a rectangle is a way of
	# drawing rather than a fourth tool, so it gets a switch of its own underneath.
	_rect_btn = _make_button("RECT FILL  (R)", Vector2(270.0, 34.0))
	_rect_btn.toggle_mode = true
	_rect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rect_btn.tooltip_text = "Drag out a whole rectangle of blocks at once; with ERASE, or on the right button, the drag clears the blocks in one"
	_rect_btn.toggled.connect(_on_rect_toggled)
	column.add_child(_rect_btn)


func _build_world_panel() -> void:
	_world_panel = _make_panel()
	_world_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_world_panel.offset_left = -276.0
	_world_panel.offset_top = 82.0
	_world_panel.offset_right = -12.0
	_world_panel.offset_bottom = -96.0
	_ui_root.add_child(_world_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_world_panel.add_child(column)

	var title := _section_label("WORLD")
	column.add_child(title)

	column.add_child(_heading_label("BACKGROUND"))

	for i in BACKGROUND_CATALOG.size():
		var spec: Dictionary = BACKGROUND_CATALOG[i]
		var button := _make_button(str(spec["name"]), Vector2(232.0, 44.0))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "Use the %s parallax backdrop" % str(spec["name"]).to_lower()
		button.icon = _swatch(spec["tint"])
		button.add_theme_constant_override("icon_max_width", 24)
		button.pressed.connect(_on_background_selected.bind(i))
		column.add_child(button)
		_background_buttons.append(button)

	column.add_child(_heading_label("VIGNETTE"))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = DEFAULT_VIGNETTE
	slider.custom_minimum_size = Vector2(232.0, 28.0)
	slider.tooltip_text = "How dark the corners of the screen get"
	slider.add_theme_stylebox_override("slider", _style(BUTTON_BG, PANEL_BORDER, 4))
	slider.value_changed.connect(_on_vignette_changed)
	column.add_child(slider)
	_vignette_slider = slider

	_vignette_value = Label.new()
	_vignette_value.add_theme_font_override("font", UI_FONT)
	_vignette_value.add_theme_font_size_override("font_size", 20)
	_vignette_value.add_theme_color_override("font_color", ACCENT)
	_vignette_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_vignette_value)

	column.add_child(_heading_label("FIREFLIES"))

	_firefly_btn = _make_button("Fireflies: ON", Vector2(232.0, 44.0))
	_firefly_btn.toggle_mode = true
	_firefly_btn.button_pressed = _fireflies
	_firefly_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_firefly_btn.tooltip_text = "Show drifting fireflies in the editor and during playtests"
	_firefly_btn.pressed.connect(_on_fireflies_pressed)
	column.add_child(_firefly_btn)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", ACCENT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _heading_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.84, 0.76, 0.64))
	return label


## A flat colour chip used as a button icon. The campaign's backdrops are mostly
## a single tint over blurred art, so for those a swatch reads clearer than a
## thumbnail of the raw texture would; items without artwork borrow it too.
func _swatch(color: Color, size: int = 8) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## One square frame out of a sprite sheet, for a palette button's icon. Both the
## checkpoint and the stall are sheets of 560px squares laid out in a row, so the
## sheet height is the frame size and the index picks the column.
func _square_frame(sheet: Texture2D, index: int) -> Texture2D:
	var frame := sheet.get_size().y
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame * float(index), 0.0, frame, frame)
	return atlas


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
	_hint.text = "LMB paint   RMB erase   R rect fill   MMB drag / WASD pan   Wheel zoom   Ctrl+Z undo   G grid"
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


func _build_online_overlay() -> void:
	_online_overlay = Control.new()
	_online_overlay.name = "OnlineOverlay"
	_online_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_online_overlay.visible = false
	_ui_root.add_child(_online_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.64)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_online_overlay.add_child(dim)

	var panel := _make_panel()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_top = -300.0
	panel.offset_right = 340.0
	panel.offset_bottom = 300.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_online_overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "ONLINE LEVELS"
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	_online_tab_publish = _make_button("PUBLISH", Vector2(150.0, 38.0))
	_online_tab_publish.pressed.connect(_show_online_publish)
	tabs.add_child(_online_tab_publish)
	_online_tab_browse = _make_button("BROWSE", Vector2(150.0, 38.0))
	_online_tab_browse.pressed.connect(_show_online_browse)
	tabs.add_child(_online_tab_browse)
	column.add_child(tabs)

	_online_publish_view = _build_online_publish_view()
	column.add_child(_online_publish_view)
	_online_browse_view = _build_online_browse_view()
	_online_browse_view.visible = false
	column.add_child(_online_browse_view)

	var close_btn := _make_button("CLOSE", Vector2(140.0, 40.0))
	close_btn.pressed.connect(_close_online_overlay)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(close_btn)
	column.add_child(close_row)


func _build_online_publish_view() -> VBoxContainer:
	var view := VBoxContainer.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 5)

	var intro := _make_form_label("Upload the level currently open in the editor. It will be published to the Holy Moley community for everyone to browse and play.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(0.0, 44.0)
	view.add_child(intro)

	view.add_child(_make_form_label("AUTHOR"))
	_publish_author_edit = _make_line_edit(LevelShare.author, "Your name")
	_publish_author_edit.max_length = 40
	view.add_child(_publish_author_edit)

	view.add_child(_make_form_label("DESCRIPTION"))
	_publish_description_edit = TextEdit.new()
	_publish_description_edit.placeholder_text = "What should players know about this level?"
	_publish_description_edit.custom_minimum_size = Vector2(0.0, 84.0)
	_publish_description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_publish_description_edit.add_theme_font_override("font", UI_FONT)
	_publish_description_edit.add_theme_font_size_override("font_size", 18)
	_publish_description_edit.add_theme_color_override("font_color", TEXT_COLOR)
	_publish_description_edit.add_theme_color_override("font_placeholder_color", Color(0.78, 0.7, 0.6, 0.75))
	_publish_description_edit.add_theme_color_override("caret_color", ACCENT)
	_publish_description_edit.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER, 4))
	_publish_description_edit.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT, 4))
	view.add_child(_publish_description_edit)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_child(spacer)

	_publish_status = Label.new()
	_publish_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_publish_status.custom_minimum_size = Vector2(0.0, 44.0)
	_publish_status.add_theme_font_override("font", UI_FONT)
	_publish_status.add_theme_font_size_override("font_size", 17)
	_publish_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.7))
	view.add_child(_publish_status)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	_publish_button = _make_button("PUBLISH LEVEL", Vector2(190.0, 42.0))
	_publish_button.pressed.connect(_on_publish_pressed)
	action_row.add_child(_publish_button)
	view.add_child(action_row)
	return view


func _build_online_browse_view() -> VBoxContainer:
	var view := VBoxContainer.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var heading := _make_form_label("COMMUNITY LEVELS")
	heading.add_theme_color_override("font_color", ACCENT)
	header.add_child(heading)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_browse_refresh_button = _make_button("REFRESH", Vector2(112.0, 36.0))
	_browse_refresh_button.pressed.connect(_refresh_online_levels)
	header.add_child(_browse_refresh_button)
	view.add_child(header)

	_browse_status = Label.new()
	_browse_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_browse_status.custom_minimum_size = Vector2(0.0, 42.0)
	_browse_status.add_theme_font_override("font", UI_FONT)
	_browse_status.add_theme_font_size_override("font_size", 17)
	_browse_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.7))
	view.add_child(_browse_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_browse_list = VBoxContainer.new()
	_browse_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browse_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_browse_list)
	view.add_child(scroll)

	var hint := _make_form_label("Loading a level downloads it into user://levels and opens it here. Press PLAY to try it, then SAVE to keep a local copy.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(0.0, 38.0)
	view.add_child(hint)
	return view


func _make_form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.84, 0.76, 0.65))
	return label


func _make_line_edit(value: String, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0.0, 38.0)
	field.add_theme_font_override("font", UI_FONT)
	field.add_theme_font_size_override("font_size", 18)
	field.add_theme_color_override("font_color", TEXT_COLOR)
	field.add_theme_color_override("font_placeholder_color", Color(0.78, 0.7, 0.6, 0.75))
	field.add_theme_color_override("caret_color", ACCENT)
	field.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER, 4))
	field.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT, 4))
	return field


func _open_online_overlay() -> void:
	_publish_author_edit.text = LevelShare.author
	_publish_status.text = ""
	_show_online_publish()
	_online_overlay.visible = true


func _close_online_overlay() -> void:
	if _online_overlay != null:
		_online_overlay.visible = false


func _show_online_publish() -> void:
	_online_publish_view.visible = true
	_online_browse_view.visible = false
	_online_tab_publish.modulate = Color.WHITE
	_online_tab_browse.modulate = Color(0.72, 0.68, 0.62, 1.0)


func _show_online_browse() -> void:
	_online_publish_view.visible = false
	_online_browse_view.visible = true
	_online_tab_publish.modulate = Color(0.72, 0.68, 0.62, 1.0)
	_online_tab_browse.modulate = Color.WHITE
	if _browse_list.get_child_count() == 0:
		_refresh_online_levels()


func _on_publish_pressed() -> void:
	_sync_level_name()
	if _tiles.is_empty() and _enemies.is_empty() and _props.is_empty():
		_publish_status.text = "Add a few blocks or entities before publishing."
		return
	var author := _publish_author_edit.text.strip_edges()
	if author.is_empty():
		author = "Anonymous"
		_publish_author_edit.text = author
	LevelShare.configure(author)
	_publish_button.disabled = true
	_publish_status.text = "Publishing to the community... (free servers may take ~1 min to wake)"
	var result: Dictionary = await LevelShare.publish(
			to_dict(), _level_name, author, _publish_description_edit.text)
	_publish_button.disabled = false
	if bool(result.get("ok", false)):
		var level: Dictionary = result.get("level", {})
		_publish_status.text = "Published! Level id: %s\nAnyone using ONLINE → BROWSE can find it." % str(level.get("id", ""))
		_toast("Published \"%s\" online" % _level_name)
		# Force the next Browse visit to pick up the new entry.
		_clear_children(_browse_list)
	else:
		_publish_status.text = "Publish failed: " + str(result.get("error", "Unknown error"))


func _refresh_online_levels() -> void:
	if _browse_refresh_button == null:
		return
	# A tab switch can ask for a refresh while an earlier one is still in
	# flight. Only the newest request is allowed to fill the list, so a slow
	# old response cannot append duplicates from the previous server.
	_browse_request_serial += 1
	var serial := _browse_request_serial
	_browse_refresh_button.disabled = true
	_browse_status.text = "Contacting the community server... (free servers may take ~1 min to wake)"
	_clear_children(_browse_list)
	var result: Dictionary = await LevelShare.fetch_levels()
	if serial != _browse_request_serial:
		return
	_browse_refresh_button.disabled = false
	if not bool(result.get("ok", false)):
		_browse_status.text = "Could not load community levels:\n" + str(result.get("error", "Unknown error"))
		return
	var levels: Array = result.get("levels", [])
	var total := int(result.get("total", levels.size()))
	_browse_status.text = "%d published level%s." % [total, "" if total == 1 else "s"]
	if levels.is_empty():
		var empty := _make_form_label("No levels have been published yet. Be the first!")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_browse_list.add_child(empty)
		return
	for raw_entry in levels:
		if raw_entry is Dictionary:
			_add_online_level_row(raw_entry)


func _add_online_level_row(entry: Dictionary) -> void:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = str(entry.get("name", "Untitled Level"))
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", ACCENT)
	card.add_child(title)

	var created := str(entry.get("created_at", "")).left(10)
	var downloads := int(entry.get("downloads", 0))
	var byline := Label.new()
	byline.text = "by %s  ·  %s  ·  %d download%s" % [
		str(entry.get("author", "Anonymous")), created, downloads,
		"" if downloads == 1 else "s"]
	byline.add_theme_font_override("font", UI_FONT)
	byline.add_theme_font_size_override("font_size", 15)
	byline.add_theme_color_override("font_color", Color(0.74, 0.67, 0.58))
	card.add_child(byline)

	var description := Label.new()
	var text := str(entry.get("description", "")).strip_edges()
	description.text = text if not text.is_empty() else "No description."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", UI_FONT)
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(0.9, 0.84, 0.75))
	card.add_child(description)

	var load_button := _make_button("LOAD", Vector2(88.0, 38.0))
	load_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_button.pressed.connect(_on_online_level_load.bind(str(entry.get("id", ""))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(card)
	row.add_child(load_button)
	_browse_list.add_child(row)
	_browse_list.add_child(HSeparator.new())


func _on_online_level_load(level_id: String) -> void:
	if not _valid_online_id(level_id):
		_browse_status.text = "That level id is not valid."
		return
	_browse_status.text = "Downloading level..."
	var result: Dictionary = await LevelShare.download_level(level_id)
	if not bool(result.get("ok", false)):
		_browse_status.text = "Could not load that level:\n" + str(result.get("error", "Unknown error"))
		return
	var data = result.get("data", null)
	if not (data is Dictionary):
		_browse_status.text = "That level did not contain readable JSON."
		return
	var path := "%s/community_%s.json" % [SAVE_DIR, level_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_browse_status.text = "Could not save the downloaded level."
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	_push_undo()
	if load_level(path):
		_editor_camera.position = _spawn_point
		var meta: Dictionary = result.get("level", {})
		_close_online_overlay()
		_toast("Loaded \"%s\" by %s" % [
			str(meta.get("name", _level_name)), str(meta.get("author", "Anonymous"))])
		_mark_dirty()
	else:
		_browse_status.text = "Downloaded, but the level could not be read."


func _sync_level_name() -> void:
	_level_name = _name_edit.text.strip_edges()
	if _level_name.is_empty():
		_level_name = DEFAULT_LEVEL_NAME
		_name_edit.text = _level_name


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _valid_online_id(level_id: String) -> bool:
	if level_id.is_empty() or level_id.length() > 64:
		return false
	for i in level_id.length():
		var ch := level_id.substr(i, 1)
		var allowed := (ch >= "a" and ch <= "z") \
				or (ch >= "A" and ch <= "Z") \
				or (ch >= "0" and ch <= "9") \
				or ch == "_" or ch == "-"
		if not allowed:
			return false
	return true


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

	for i in ITEM_CATALOG.size():
		var spec: Dictionary = ITEM_CATALOG[i]
		var button := Button.new()
		button.text = str(spec["name"])
		var item := load(str(spec["value"])) as ItemData
		if item != null:
			button.icon = _item_icon(item)
		button.toggle_mode = true
		# One full-width row per entry. The palette's inner width is what the enemy
		# grid's two 136px columns add up to, and these names run long enough
		# ("Holy Water", "Ice Bomb") that halving it would cut them off.
		button.custom_minimum_size = Vector2(136.0 * 2.0 + 6.0, 52.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", TEXT_COLOR)
		button.add_theme_constant_override("icon_max_width", 40)
		button.add_theme_stylebox_override("normal", _style(BUTTON_BG, PANEL_BORDER, 4))
		button.add_theme_stylebox_override("hover", _style(BUTTON_HOVER, ACCENT, 4))
		button.add_theme_stylebox_override("pressed", _style(BUTTON_PRESSED, ACCENT, 4))
		button.add_theme_stylebox_override("focus", _style(BUTTON_HOVER, ACCENT, 4))
		button.pressed.connect(_on_item_selected.bind(i))
		_item_grid.add_child(button)
		_item_buttons.append(button)


## Items that ship an icon texture show it; the rest get a chip of their own
## icon colour, which is what the dropped pickup falls back to in game too.
func _item_icon(item: ItemData) -> Texture2D:
	if item.icon_texture != null:
		return item.icon_texture
	return _swatch(item.icon_color, 32)


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


func _on_chest_selected() -> void:
	_tool = TOOL_CHEST
	_refresh_tool_buttons()


func _on_portal_selected() -> void:
	_tool = TOOL_PORTAL
	_refresh_tool_buttons()


func _on_checkpoint_selected() -> void:
	_tool = TOOL_CHECKPOINT
	_refresh_tool_buttons()


func _on_gilbert_selected() -> void:
	_tool = TOOL_GILBERT
	_refresh_tool_buttons()


func _on_item_selected(index: int) -> void:
	_selected_item = index
	_tool = TOOL_ITEM
	_refresh_tool_buttons()


func _select_tool(tool: int) -> void:
	_tool = tool
	_refresh_tool_buttons()


## Rectangle filling is a mode rather than a tool, so it stays on while the author
## moves between block types and between tools. It simply has nothing to do for
## the tools that place a single object.
func _on_rect_toggled(on: bool) -> void:
	_rect_mode = on
	_rect_active = false
	_overlay.queue_redraw()


func _set_tab(tab: int) -> void:
	_tab = tab
	_block_grid.visible = tab == TAB_BLOCKS
	_enemy_grid.visible = tab == TAB_ENEMIES
	_items_box.visible = tab == TAB_ITEMS
	match tab:
		TAB_ENEMIES:
			_tool = TOOL_ENEMY
		TAB_ITEMS:
			_tool = TOOL_ITEM
		_:
			_tool = TOOL_BLOCK
	_refresh_tool_buttons()


func _refresh_tool_buttons() -> void:
	_blocks_tab.button_pressed = _tab == TAB_BLOCKS
	_enemies_tab.button_pressed = _tab == TAB_ENEMIES
	_items_tab.button_pressed = _tab == TAB_ITEMS
	_erase_btn.button_pressed = _tool == TOOL_ERASE
	_spawn_btn.button_pressed = _tool == TOOL_SPAWN
	_rect_btn.set_pressed_no_signal(_rect_mode)
	_chest_btn.button_pressed = _tool == TOOL_CHEST
	_portal_btn.button_pressed = _tool == TOOL_PORTAL
	_checkpoint_btn.button_pressed = _tool == TOOL_CHECKPOINT
	_gilbert_btn.button_pressed = _tool == TOOL_GILBERT
	for coords in _block_buttons:
		var button: Button = _block_buttons[coords]
		button.button_pressed = _tool == TOOL_BLOCK and coords == _selected_block
	for i in _enemy_buttons.size():
		var button: Button = _enemy_buttons[i]
		button.button_pressed = _tool == TOOL_ENEMY and i == _selected_enemy
	for i in _item_buttons.size():
		var button: Button = _item_buttons[i]
		button.button_pressed = _tool == TOOL_ITEM and i == _selected_item


# -------------------------------------------------------------- UI handlers

func _on_name_changed(text: String) -> void:
	_level_name = text
	_mark_dirty()


func _on_background_selected(index: int) -> void:
	_background_index = index
	_apply_world()
	_mark_dirty()


func _on_vignette_changed(value: float) -> void:
	_vignette = value
	_apply_vignette()
	if _vignette_value != null:
		_vignette_value.text = "%d%%" % roundi(value * 100.0)
	_mark_dirty()


func _on_fireflies_pressed() -> void:
	_fireflies = _firefly_btn.button_pressed
	_apply_fireflies()
	_refresh_world_ui()
	_mark_dirty()


func _on_save_pressed() -> void:
	_sync_level_name()
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
	# The level is written before the wipe rather than on the way out, so the
	# work is on disk even if the transition is interrupted.
	_save_now()
	# Back to the title screen the way every other scene is left: the same circle
	# wipe the levels use, so the editor reads as part of the game instead of
	# cutting straight to the menu.
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(TITLE_SCENE)


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
