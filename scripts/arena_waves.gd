extends Node

const ANTS_SCENE := "res://scenes/antenemy.tscn"
const FONT_PATH := "res://Baby Doll.otf"
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

const WAVE_ENEMIES: Array[Dictionary] = [
	{"scene": "res://scenes/goblinenemy.tscn", "name": "GOBLINS"},
	{"scene": "res://scenes/beetleenemy.tscn", "name": "BEETLES"},
	{"scene": "res://scenes/slimeenemy.tscn", "name": "SLIMES"},
	{"scene": "res://scenes/hornet_enemy.tscn", "name": "HORNETS"},
]

var _wave := -1
var _alive := 0
var _active := false
var _spawn_points: Array[Vector2] = []
var _banner: Label = null

func _ready() -> void:
	var root := get_parent()
	for child in root.get_children():
		var node := child as Node2D
		if node != null and child.scene_file_path == ANTS_SCENE:
			_spawn_points.append(node.global_position)
			_track(child)
	_active = _spawn_points.size() > 0
	_build_banner()
	_show_wave_name("ANTS")

func _track(node: Node) -> void:
	_alive += 1
	node.tree_exited.connect(_on_enemy_killed)

func _on_enemy_killed() -> void:
	_alive -= 1
	if not _active or _alive > 0:
		return
	call_deferred("_spawn_next_wave")

func _spawn_next_wave() -> void:
	if not is_inside_tree() or not is_instance_valid(get_parent()):
		return
	_wave += 1
	if _wave >= WAVE_ENEMIES.size():
		_active = false
		_show_wave_name("CLEARED!")
		if is_inside_tree():
			get_tree().create_timer(0.8).timeout.connect(_break_arena_blocks)
		return
	var entry: Dictionary = WAVE_ENEMIES[_wave]
	var scene: PackedScene = load(entry["scene"] as String)
	for point in _spawn_points:
		var enemy := scene.instantiate()
		_track(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = point
		get_parent().add_child.call_deferred(enemy)
	_show_wave_name(entry["name"] as String)

func _break_arena_blocks() -> void:
	if not is_inside_tree() or not is_instance_valid(get_parent()):
		return
	var tilemap: TileMap = get_parent().get_node_or_null("TileMap2") as TileMap
	if tilemap == null:
		return
	for cell in tilemap.get_used_cells(0):
		TileBreakSFX.break_tile(tilemap, cell, get_parent(), true)

func _show_wave_name(text_value: String) -> void:
	if _banner:
		var tween := create_tween()
		_banner.modulate.a = 1.0
		_banner.text = text_value
		tween.tween_interval(1.6)
		tween.tween_property(_banner, "modulate:a", 0.0, 0.6)

func _build_banner() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WaveBannerLayer"
	layer.layer = 40
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -350.0
	label.offset_right = 350.0
	label.offset_top = 70.0
	label.offset_bottom = 130.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var font := load(FONT_PATH) as Font
	if font != null:
		label.add_theme_font_override("font", font)
	layer.add_child(label)
	add_child(layer)
	_banner = label