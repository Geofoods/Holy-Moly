extends Node

signal acorn_changed

const SAVE_PATH := "user://holy_moley_progress.cfg"

const ACORN_LEVELS: Array[String] = [
	"res://scenes/level1.tscn",
	"res://scenes/level_02.tscn",
	"res://scenes/level_03.tscn",
	"res://scenes/level_04.tscn",
	"res://scenes/level_05.tscn",
	"res://scenes/level_06.tscn",
	"res://scenes/level_07.tscn",
	"res://scenes/level_08.tscn",
	"res://scenes/level_hive.tscn",
	"res://scenes/level_09.tscn",
	"res://scenes/level_10.tscn",
	"res://scenes/level_11.tscn",
	"res://scenes/level_12.tscn",
]

var acorns := {}
var completed := {}
## Scenes the mole has actually stood in at least once. Gates the map's travel
## list, so a destination cannot be teleported to until it has been walked to.
## Kept apart from `completed`, which means a level was finished - the hub
## scenes have no results screen and so would never appear in it, which would
## leave both travel destinations locked forever.
var visited := {}
var queen_defeated := false
var corrupted_defeated := false
var boss_rush_cleared := false
var arena_completed := false
var best_combo := 0

## Banked respawn station. `respawn_scene` is the scene the mole is set to
## arrive in, and the station in that scene works out the arrival spot from its
## own pad. `respawn_position` is where the mole stood when it banked the pad,
## kept as a record of the banking rather than used to place the arrival.
var respawn_scene := ""
var respawn_position := Vector2.ZERO

## Transient, never saved. Set when a death or a map teleport sends the mole back
## to the banked station and consumed once by the mole on arrival, so only the
## station the mole is actually arriving at plays the materialise animation.
var respawn_pending := false

var acorn_total := ACORN_LEVELS.size()

var _hub_layer: CanvasLayer = null
var _hub_label: Label = null

func _ready() -> void:
	load_progress()
	_build_hub_layer()
	get_tree().scene_changed.connect(_on_scene_changed)

## Records arrivals so the travel list can tell a place the mole has been from one
## it has not. Driven off the tree rather than off individual level scripts, so a
## scene cannot be reached by a route that forgets to announce itself. `current_scene`
## is already the incoming one by the time this fires.
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	mark_visited(str(scene.scene_file_path))

func _process(_delta: float) -> void:
	var cs = get_tree().current_scene
	if cs == null:
		return
	var path := str(cs.scene_file_path)
	if _hub_layer != null:
		_hub_layer.visible = path == "res://scenes/map.tscn"
		if _hub_layer.visible and _hub_label != null:
			_hub_label.text = "ACORNS   %d / %d" % [acorns.size(), acorn_total]

func _build_hub_layer() -> void:
	_hub_layer = CanvasLayer.new()
	_hub_layer.name = "AcornHubLayer"
	_hub_layer.layer = 30
	var label := Label.new()
	label.name = "AcornHubLabel"
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.offset_left = -250.0
	label.offset_right = 250.0
	label.offset_top = 8.0
	label.offset_bottom = 48.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hub_layer.add_child(label)
	add_child(_hub_layer)
	_hub_layer.visible = false
	_hub_label = label

func has_acorn(path: String) -> bool:
	return acorns.has(path)

func acorn_count() -> int:
	return acorns.size()

func mark_acorn(path: String) -> void:
	if acorns.has(path):
		return
	acorns[path] = true
	save_progress()
	acorn_changed.emit()

func mark_level_complete(path: String) -> void:
	if not path.is_empty():
		completed[path] = true
	save_progress()

func is_level_complete(path: String) -> bool:
	return completed.has(path)

## Notes that the mole has stood in `path`. Idempotent, and only writes to disk
## the first time a scene is seen so arrivals do not rewrite the save each time.
func mark_visited(path: String) -> void:
	if path.is_empty() or visited.has(path):
		return
	visited[path] = true
	save_progress()

## Whether the mole has been to `path` yet, which is what makes it a legal
## teleport destination.
func has_visited(path: String) -> bool:
	return visited.has(path)

func mark_queen_defeated() -> void:
	if not queen_defeated:
		queen_defeated = true
		save_progress()

func mark_corrupted_defeated() -> void:
	if not corrupted_defeated:
		corrupted_defeated = true
		save_progress()

func mark_boss_rush_cleared() -> void:
	if not boss_rush_cleared:
		boss_rush_cleared = true
		save_progress()

func mark_arena_completed() -> void:
	if not arena_completed:
		arena_completed = true
		save_progress()

func is_arena_completed() -> bool:
	return arena_completed

func update_best_combo(value: int) -> void:
	if value > best_combo:
		best_combo = value
		save_progress()

func has_respawn() -> bool:
	return not respawn_scene.is_empty() and ResourceLoader.exists(respawn_scene)

## Banks `scene_path` as the respawn station and remembers the spot the mole
## was standing, then writes both to disk so a checkpoint survives a restart.
func set_respawn(scene_path: String, pos: Vector2) -> void:
	respawn_scene = scene_path
	respawn_position = pos
	save_progress()

func clear_respawn() -> void:
	respawn_scene = ""
	respawn_position = Vector2.ZERO
	respawn_pending = false
	save_progress()

## Read-and-clear, so the arrival animation fires exactly once per respawn
## instead of replaying on every scene load afterwards.
func take_respawn_pending() -> bool:
	var pending := respawn_pending
	respawn_pending = false
	return pending

func save_progress() -> void:
	var cfg := ConfigFile.new()
	for p in acorns:
		cfg.set_value("acorns", p, true)
	for p in completed:
		cfg.set_value("completed", p, true)
	for p in visited:
		cfg.set_value("visited", p, true)
	cfg.set_value("bosses", "queen", queen_defeated)
	cfg.set_value("bosses", "corrupted", corrupted_defeated)
	cfg.set_value("bosses", "rush", boss_rush_cleared)
	cfg.set_value("arena", "completed", arena_completed)
	cfg.set_value("meta", "best_combo", best_combo)
	cfg.set_value("respawn", "scene", respawn_scene)
	cfg.set_value("respawn", "position", respawn_position)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section("acorns"):
		for k in cfg.get_section_keys("acorns"):
			acorns[k] = true
	if cfg.has_section("completed"):
		for k in cfg.get_section_keys("completed"):
			completed[k] = true
	if cfg.has_section("visited"):
		for k in cfg.get_section_keys("visited"):
			visited[k] = true
	queen_defeated = bool(cfg.get_value("bosses", "queen", false))
	corrupted_defeated = bool(cfg.get_value("bosses", "corrupted", false))
	boss_rush_cleared = bool(cfg.get_value("bosses", "rush", false))
	arena_completed = bool(cfg.get_value("arena", "completed", false))
	best_combo = int(cfg.get_value("meta", "best_combo", 0))
	respawn_scene = str(cfg.get_value("respawn", "scene", ""))
	var pos = cfg.get_value("respawn", "position", Vector2.ZERO)
	if pos is Vector2:
		respawn_position = pos