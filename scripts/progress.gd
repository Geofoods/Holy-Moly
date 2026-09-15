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
]

var acorns := {}
var completed := {}
var queen_defeated := false
var corrupted_defeated := false
var boss_rush_cleared := false
var best_combo := 0

var acorn_total := ACORN_LEVELS.size()

var _last_scene_path := ""
var _spawned_scene := ""
var _spawn_pending := false
var _acorn_scene := preload("res://scenes/golden_acorn.tscn")
var _hub_layer: CanvasLayer = null
var _hub_label: Label = null

func _ready() -> void:
	load_progress()
	_build_hub_layer()

func _process(_delta: float) -> void:
	var cs = get_tree().current_scene
	if cs == null:
		return
	var path := str(cs.scene_file_path)
	if path != _last_scene_path:
		_last_scene_path = path
		_spawn_pending = false
		if path in ACORN_LEVELS and not acorns.has(path):
			_spawned_scene = path
		else:
			_spawned_scene = ""
	else:
		if _spawned_scene != "" and not _spawn_pending:
			_spawn_pending = true
			get_tree().create_timer(0.6).timeout.connect(_spawn_acorn)
	if _hub_layer != null:
		_hub_layer.visible = path == "res://scenes/map.tscn"
		if _hub_layer.visible and _hub_label != null:
			_hub_label.text = "ACORNS   %d / %d" % [acorns.size(), acorn_total]

func _spawn_acorn() -> void:
	_spawn_pending = false
	var cs = get_tree().current_scene
	if cs == null:
		return
	var path := str(cs.scene_file_path)
	if path != _spawned_scene or acorns.has(path):
		_spawned_scene = ""
		return
	var acorn = _acorn_scene.instantiate()
	var mole = get_tree().get_first_node_in_group("mole") as Node2D
	var anchor := Vector2(220, 60)
	if mole != null and is_instance_valid(mole):
		anchor = mole.global_position
	acorn.level_path = path
	cs.add_child(acorn)
	acorn.global_position = anchor + Vector2(70, -70)

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

func update_best_combo(value: int) -> void:
	if value > best_combo:
		best_combo = value
		save_progress()

func save_progress() -> void:
	var cfg := ConfigFile.new()
	for p in acorns:
		cfg.set_value("acorns", p, true)
	for p in completed:
		cfg.set_value("completed", p, true)
	cfg.set_value("bosses", "queen", queen_defeated)
	cfg.set_value("bosses", "corrupted", corrupted_defeated)
	cfg.set_value("bosses", "rush", boss_rush_cleared)
	cfg.set_value("meta", "best_combo", best_combo)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in cfg.get_section_keys("acorns"):
		acorns[k] = true
	for k in cfg.get_section_keys("completed"):
		completed[k] = true
	queen_defeated = bool(cfg.get_value("bosses", "queen", false))
	corrupted_defeated = bool(cfg.get_value("bosses", "corrupted", false))
	boss_rush_cleared = bool(cfg.get_value("bosses", "rush", false))
	best_combo = int(cfg.get_value("meta", "best_combo", 0))