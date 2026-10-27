extends Node2D

## Normal-gameplay host for a community level published from the Level Editor.
##
## Unlike the editor's playtest, this is not a preview: it has the campaign's
## HUD, pause menu and field guide, deaths leave for the game over screen, and
## the portal finishes the run back at the Level Browser. The level JSON is
## rebuilt here from the same data the editor saves, but none of the editor's
## tools or playtest bar are loaded.

const MOLE_SCENE := preload("res://scenes/mole.tscn")
const CHEST_SCENE := preload("res://chest.tscn")
const DROPPED_ITEM_SCENE := preload("res://scenes/dropped_item.tscn")
const PORTAL_SCENE := preload("res://scenes/level_portal.tscn")
const RESPAWN_STATION_SCENE := preload("res://scenes/respawn_station.tscn")
const CANDLE_SCENE := preload("res://candle.tscn")
const FIREFLY_SCENE := preload("res://scenes/firefly_spawner.tscn")
const SCENE_TRANSITION := preload("res://scenes/scene_transition.tscn")
const UI_FONT := preload("res://Baby Doll.otf")

const BROWSER_SCENE := "res://scenes/level_browser.tscn"
const TILE_LAYER := 0
const TERRAIN_SOURCE := 0

## The campaign levels scale the mole down to a quarter so he stands roughly
## one tile tall next to the half-scaled 160px TileSet. Matches the Level Editor,
## so a community level plays at the size its author previewed.
const MOLE_SCALE := Vector2(0.25, 0.25)
const MOLE_CAMERA_SCALE := Vector2(4.0, 4.0)
const MOLE_CAMERA_ZOOM := Vector2(0.65, 0.65)
const HEART_SCALE := Vector2(0.24147864, 0.24147864)

const DEFAULT_MUSIC_ID := "grotto"
const COMPLETION_HOLD := 1.6

const ENEMY_SCENES := {
	"Ant": "res://scenes/antenemy.tscn",
	"Beetle": "res://scenes/beetleenemy.tscn",
	"Goblin": "res://scenes/goblinenemy.tscn",
	"Hornet": "res://scenes/hornet_enemy.tscn",
	"Slime": "res://scenes/slimeenemy.tscn",
}

## The merchant's four item pickups. A downloaded level may only name one of
## these resources, never an arbitrary path from the network.
const ITEM_PATHS: Array[String] = [
	"res://resources/drill.tres",
	"res://resources/bomb.tres",
	"res://resources/ice_bomb.tres",
	"res://resources/holy_water.tres",
]

const BACKGROUND_SCENES: Array[String] = [
	"res://scenes/parallax_background.tscn",
	"res://scenes/parallax_background2.tscn",
	"res://scenes/parallax_background3.tscn",
]

const MUSIC_PATHS := {
	"grotto": "res://nojisuma-grotto-120967.mp3",
	"village": "res://Stardew Valley OST - Pelican Town.mp3",
	"slime_valley": "res://Shimmer - Sinjin Hawke - FRACTAL FANTASY (128k).mp3",
	"mines": "res://Stardew Valley OST - Mines (The Lava Dwellers) - Lewie G (128k).mp3",
	"corrupted_heart": "res://Grimm (Hollow Knight_ The Grimm Troupe).mp3",
	"sealed_vessel": "res://Hollow Knight OST - Sealed Vessel.mp3",
	"arena": "res://Hollow Knight OST - Nosk [youaretube.com].mp3",
}

@onready var _tilemap: TileMap = $TileMap
@onready var _entities: Node2D = $Entities
@onready var _background: Node2D = $ParallaxBackground
@onready var _vignette: ColorRect = $VignetteLayer/VignetteRect
@onready var _pause_menu: CanvasLayer = $PauseMenu

var _level_path := ""
var _level_name := "Community Level"
var _spawn_point := Vector2.ZERO
var _tile_world := 80.0
var _background_index := 0
var _vignette_amount := 0.55
var _fireflies := true
var _music_path := ""
var _weapon_override := false
var _level_weapons: Array[String] = []
var _mole: Node = null
var _finishing := false
var _saved_shop: Dictionary = {}


func _ready() -> void:
	_tile_world = float(_tilemap.tile_set.tile_size.x) * absf(_tilemap.scale.x)
	_hide_pause_menu_map()
	_apply_heart_scale()

	var level_path := LevelShare.community_play_level()
	if level_path.is_empty() or not FileAccess.file_exists(level_path):
		_leave_for_browser()
		return
	var file := FileAccess.open(level_path, FileAccess.READ)
	if file == null:
		_leave_for_browser()
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary) or not (parsed.has("blocks") and parsed.has("enemies")):
		_leave_for_browser()
		return
	_level_path = level_path
	_read_header(parsed)
	_build_level(parsed)
	_apply_world()
	_prepare_loadout()
	_spawn_mole()
	_create_pit()


## Reads and validates everything that is not a world object. Any value a save
## no longer recognises falls back to the safe default rather than loading an
## arbitrary resource name out of a downloaded file.
func _read_header(data: Dictionary) -> void:
	_level_name = str(data.get("name", "Community Level")).strip_edges()
	if _level_name.is_empty():
		_level_name = "Community Level"
	var spawn = data.get("spawn", null)
	if spawn is Array and spawn.size() >= 2:
		_spawn_point = Vector2(float(spawn[0]), float(spawn[1]))
	_background_index = clampi(int(data.get("background", 0)), 0, BACKGROUND_SCENES.size() - 1)
	_vignette_amount = clampf(float(data.get("vignette", 0.55)), 0.0, 1.0)
	_fireflies = bool(data.get("fireflies", true))
	var music_id := str(data.get("music", DEFAULT_MUSIC_ID))
	_music_path = str(MUSIC_PATHS.get(music_id, MUSIC_PATHS[DEFAULT_MUSIC_ID]))
	var weapons = data.get("weapons", null)
	if weapons is Array:
		_weapon_override = true
		_level_weapons.clear()
		for value in weapons:
			var id := str(value)
			if _is_weapon_id(id) and id not in _level_weapons:
				_level_weapons.append(id)
		if "shovel" not in _level_weapons:
			_level_weapons.push_front("shovel")
	else:
		_weapon_override = false
		_level_weapons = _all_weapon_ids()


func _build_level(data: Dictionary) -> void:
	_tilemap.clear_layer(TILE_LAYER)
	for row in data.get("blocks", []):
		if not (row is Array and row.size() >= 5):
			continue
		var cell := Vector2i(int(row[3]), int(row[4]))
		_tilemap.set_cell(TILE_LAYER, cell, int(row[0]), Vector2i(int(row[1]), int(row[2])))

	for row in data.get("enemies", []):
		if not (row is Array and row.size() >= 3):
			continue
		var scene_path := str(ENEMY_SCENES.get(str(row[0]), ""))
		if scene_path.is_empty():
			continue
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		var enemy := packed.instantiate() as Node2D
		if enemy == null:
			continue
		_entities.add_child(enemy)
		enemy.global_position = Vector2(float(row[1]), float(row[2]))

	var checkpoint := LevelShare.community_checkpoint(_level_path)
	for prop in data.get("props", []):
		if not (prop is Array and prop.size() >= 4):
			continue
		var node := _make_prop(str(prop[0]), str(prop[1]))
		if node == null:
			continue
		_entities.add_child(node)
		node.global_position = Vector2(float(prop[2]), float(prop[3]))
		if str(prop[0]) == "checkpoint":
			_restore_checkpoint_light(node, checkpoint)


## Rebuilds one placed prop. Only the values the Level Editor can actually place
## are accepted, so a hand-edited JSON cannot make this scene load an arbitrary
## path.
func _make_prop(kind: String, value: String) -> Node2D:
	match kind:
		"chest":
			return CHEST_SCENE.instantiate() as Node2D
		"item":
			if value not in ITEM_PATHS:
				return null
			var item := load(value) as ItemData
			if item == null:
				return null
			var dropped = DROPPED_ITEM_SCENE.instantiate()
			dropped.item_data = item
			dropped.start_floating = true
			return dropped as Node2D
		"portal":
			var portal := PORTAL_SCENE.instantiate()
			portal.entered.connect(_on_portal_entered)
			return portal as Node2D
		"checkpoint":
			var station := RESPAWN_STATION_SCENE.instantiate()
			station.use_progress = false
			station.banked.connect(_on_checkpoint_banked)
			return station as Node2D
		"candle":
			return CANDLE_SCENE.instantiate() as Node2D
	return null


func _apply_world() -> void:
	_background.visible = _background_index == 0
	if _background_index > 0:
		var packed := load(BACKGROUND_SCENES[_background_index]) as PackedScene
		if packed != null:
			var backdrop := packed.instantiate() as Node2D
			if backdrop != null:
				backdrop.name = "CommunityBackground"
				add_child(backdrop)
				move_child(backdrop, _background.get_index() + 1)
	var material := _vignette.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("darkness", _vignette_amount)
	if _fireflies:
		var spawner := FIREFLY_SCENE.instantiate() as Node2D
		if spawner != null:
			spawner.name = "FireflySpawner"
			add_child(spawner)
	LevelMusic.set_bed_override(_music_path)


func _prepare_loadout() -> void:
	Inventory.initialize()
	Inventory.player_health = Inventory.MAX_HEALTH
	var owned_snapshot: Array[String] = []
	owned_snapshot.assign(Shop.owned)
	_saved_shop = {
		"owned": owned_snapshot,
		"melee": Shop.equipped_melee_id,
		"ranged": Shop.equipped_ranged_id,
		"ranged_active": Shop.ranged_active,
		"coins": Shop.coins,
	}
	# A community run must not bank its coins or unlock its authored weapons in
	# the player's real shop save. The level's set is borrowed for this run only.
	Shop.suppress_save = true
	if _weapon_override:
		var selected: Array[String] = []
		for id in _level_weapons:
			if _is_weapon_id(id) and id not in selected:
				selected.append(id)
		if "shovel" not in selected:
			selected.push_front("shovel")

		var kept: Array[String] = []
		for id in Shop.owned:
			if not _is_weapon_id(str(id)):
				kept.append(str(id))
		for id in selected:
			if id not in kept:
				kept.append(id)
		Shop.owned = kept

		var starting_ranged := ""
		for weapon in Shop.weapon_catalog:
			if weapon.id in selected and weapon.weapon_type == WeaponData.Type.RANGED:
				starting_ranged = weapon.id
		Shop.equipped_ranged_id = starting_ranged

	if "shovel" not in Shop.owned:
		Shop.owned.push_front("shovel")
	Shop.equipped_melee_id = "shovel"
	Shop.ranged_active = false
	Shop.loadout_changed.emit()


func _spawn_mole() -> void:
	var checkpoint := LevelShare.community_checkpoint(_level_path)
	var spawn := _spawn_point
	if checkpoint.has("position"):
		spawn = checkpoint["position"]

	var mole := MOLE_SCENE.instantiate()
	mole.name = "Mole"
	mole.scale = MOLE_SCALE
	mole.position = spawn
	# Not a playtest: a death follows the campaign's route to game_over.tscn.
	mole.playtest = false
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.scale = MOLE_CAMERA_SCALE
	camera.zoom = MOLE_CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	mole.add_child(camera)
	add_child(mole)
	mole.global_position = spawn
	_mole = mole
	camera.make_current()


## A custom level has no campaign exit zone to kill a fall, so a wide pit sits a
## few tiles under the lowest authored block, exactly like the Level Editor's
## own playtest floor. Touching it ends the run through the normal death path.
func _create_pit() -> void:
	var used := _tilemap.get_used_rect()
	var bottom := _spawn_point.y + 2400.0
	if used.size != Vector2i.ZERO:
		bottom = float(used.position.y + used.size.y) * _tile_world + _tile_world * 3.0
	var pit := Area2D.new()
	pit.name = "CommunityPit"
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


func _on_pit_body_entered(body: Node) -> void:
	if _finishing or body != _mole:
		return
	if body.has_method("_die"):
		body.call("_die")


func _on_checkpoint_banked(station: Node) -> void:
	if not is_instance_valid(station):
		return
	var spawn: Vector2 = station.call("spawn_point")
	LevelShare.set_community_checkpoint(_level_path, spawn, station.global_position)


## On a retry after death the scene is rebuilt from JSON. The station that was
## banked is lit again so the checkpoint reads as still active, and the mole is
## spawned at its saved point in _spawn_mole().
func _restore_checkpoint_light(station: Node, checkpoint: Dictionary) -> void:
	if checkpoint.is_empty() or not checkpoint.has("station"):
		return
	var saved: Vector2 = checkpoint["station"]
	if station.global_position.distance_to(saved) <= 1.0:
		station.set("_banked_here", true)


func _on_portal_entered() -> void:
	if _finishing:
		return
	_finishing = true
	SFX.play_ui("item_pickup", -3.0, 1.5)
	if is_instance_valid(_mole):
		_mole.set("invulnerable", true)
		_mole.set_physics_process(false)
		_mole.process_mode = Node.PROCESS_MODE_DISABLED
	_show_completion()
	await get_tree().create_timer(COMPLETION_HOLD).timeout
	LevelShare.clear_community_play()
	_leave_for_browser()


func _show_completion() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CompletionLayer"
	layer.layer = 120
	add_child(layer)
	var label := Label.new()
	label.text = "LEVEL COMPLETE!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 54)
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12))
	label.add_theme_constant_override("outline_size", 10)
	label.modulate.a = 0.0
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var subtitle := Label.new()
	subtitle.text = _level_name
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_font_override("font", UI_FONT)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12))
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.modulate.a = 0.0
	layer.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subtitle.offset_top = 80.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.22)
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.3)


func _leave_for_browser() -> void:
	var transition := SCENE_TRANSITION.instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(BROWSER_SCENE)


func _hide_pause_menu_map() -> void:
	# The campaign map cannot travel into a downloaded level, so a community run
	# hides that one pause entry rather than opening a map that cannot represent
	# where the player is.
	var map_button := _pause_menu.get_node_or_null(
			"CenterContainer/PausePanel/VBoxContainer/ButtonContainer/MapButton")
	if map_button != null:
		map_button.visible = false


func _apply_heart_scale() -> void:
	var heart := get_node_or_null("CanvasLayer/heart") as Node2D
	if heart != null:
		heart.scale = HEART_SCALE


func _is_weapon_id(id: String) -> bool:
	for weapon in Shop.weapon_catalog:
		if weapon.id == id:
			return true
	return false


func _all_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon in Shop.weapon_catalog:
		if weapon.weapon_type != WeaponData.Type.ABILITY:
			ids.append(weapon.id)
	return ids


func _restore_shop() -> void:
	if _saved_shop.is_empty():
		return
	var owned: Array[String] = []
	owned.assign(_saved_shop["owned"])
	Shop.owned = owned
	Shop.equipped_melee_id = str(_saved_shop["melee"])
	Shop.equipped_ranged_id = str(_saved_shop["ranged"])
	Shop.ranged_active = bool(_saved_shop["ranged_active"])
	Shop.coins = int(_saved_shop["coins"])
	Shop.suppress_save = false
	Shop.coins_changed.emit(Shop.coins)
	_saved_shop = {}


func _exit_tree() -> void:
	_restore_shop()
	LevelMusic.clear_bed_override()
	LevelMusic.stop_bed(0.0)
	Engine.time_scale = 1.0
