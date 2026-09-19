extends Node2D

@export_range(10, 12) var level_id: int = 10

var platforms: Array[Rect2] = []
var accent := Color(0.95, 0.42, 0.72, 1.0)
var accent_dark := Color(0.32, 0.12, 0.26, 1.0)
var platform_dark := Color(0.16, 0.09, 0.12, 1.0)
var platform_mid := Color(0.34, 0.19, 0.18, 1.0)
var terrain_tilemap: TileMap = null

const ENEMIES := {
	"ant": "res://scenes/antenemy.tscn",
	"goblin": "res://scenes/goblinenemy.tscn",
	"beetle": "res://scenes/beetleenemy.tscn",
	"slime": "res://scenes/slimeenemy.tscn",
}

func _ready() -> void:
	_build_layout()
	_build_tilemap()
	_build_encounters()
	_build_exit()
	queue_redraw()

func _build_layout() -> void:
	match level_id:
		10:
			# Long switchbacks: the campaign levels use wide rooms with several
			# tile-built sections, so this bonus route stretches across eight caves.
			platforms = [
				Rect2(-420, 180, 920, 90), Rect2(660, 300, 560, 70),
				Rect2(1380, 190, 620, 70), Rect2(2160, 330, 640, 70),
				Rect2(2960, 210, 700, 70), Rect2(3820, 350, 820, 90),
				Rect2(4800, 220, 720, 70), Rect2(5680, 330, 760, 70),
				Rect2(6600, 190, 920, 90),
			]
		11:
			# Beetle gauntlet: broad arenas separated by low steps and pits.
			platforms = [
				Rect2(-420, 180, 860, 90), Rect2(520, 180, 780, 90),
				Rect2(1440, 260, 560, 80), Rect2(2140, 150, 820, 90),
				Rect2(3100, 280, 680, 80), Rect2(3920, 180, 920, 90),
				Rect2(4980, 260, 700, 80), Rect2(5820, 180, 1080, 90),
				Rect2(7100, 280, 760, 80),
			]
		12:
			# Lantern maze: a long rising route with small ledges and deep drops.
			platforms = [
				Rect2(-420, 180, 680, 90), Rect2(420, 330, 420, 70),
				Rect2(1000, 170, 460, 70), Rect2(1600, 320, 420, 70),
				Rect2(2160, 150, 520, 70), Rect2(2820, 300, 500, 70),
				Rect2(3460, 160, 620, 80), Rect2(4220, 300, 760, 90),
				Rect2(5120, 180, 580, 70), Rect2(5840, 320, 620, 70),
				Rect2(6600, 160, 820, 90),
			]

func _build_tilemap() -> void:
	terrain_tilemap = get_node_or_null("TileMap") as TileMap
	if terrain_tilemap == null:
		terrain_tilemap = TileMap.new()
		terrain_tilemap.name = "TileMap"
		terrain_tilemap.tile_set = preload("res://tileset.tres")
		terrain_tilemap.scale = Vector2(0.5, 0.5)
		add_child(terrain_tilemap)
	if terrain_tilemap.tile_set == null:
		terrain_tilemap.tile_set = preload("res://tileset.tres")
	# The existing atlas uses 160px cells; the game's level TileMaps are scaled
	# to half-size, so each terrain cell occupies an 80px world-space square.
	for rect in platforms:
		var start_x := floori(rect.position.x / 80.0)
		var end_x := ceili(rect.end.x / 80.0)
		var row := floori(rect.position.y / 80.0)
		for cell_x in range(start_x, end_x):
			for depth in range(0, 2):
				# The campaign stores solid terrain in consecutive tile rows; do the
				# same here so every ledge has a proper tile-built underside.
				var atlas_x := posmod(cell_x + depth, 9)
				terrain_tilemap.set_cell(0, Vector2i(cell_x, row + depth), 0, Vector2i(atlas_x, 0))

func _build_encounters() -> void:
	match level_id:
		10:
			_spawn_enemy("ant", Vector2(690, 245))
			_spawn_enemy("slime", Vector2(1300, 135))
			_spawn_enemy("ant", Vector2(1880, 275))
			_spawn_enemy("goblin", Vector2(2530, 155))
			_spawn_enemy("beetle", Vector2(3290, 295))
			_spawn_enemy("slime", Vector2(4150, 295))
			_spawn_enemy("ant", Vector2(5150, 165))
			_spawn_enemy("goblin", Vector2(6120, 275))
			_spawn_enemy("beetle", Vector2(7040, 115))
			_spawn_chest(Vector2(1250, 130))
			_spawn_chest(Vector2(3650, 270))
			_spawn_chest(Vector2(5480, 250))
			_spawn_candle(Vector2(420, 130))
			_spawn_candle(Vector2(2760, 280))
			_spawn_candle(Vector2(6440, 140))
		11:
			_spawn_enemy("beetle", Vector2(650, 120))
			_spawn_enemy("beetle", Vector2(870, 120))
			_spawn_enemy("goblin", Vector2(1390, 200))
			_spawn_enemy("slime", Vector2(1980, 90))
			_spawn_enemy("beetle", Vector2(2230, 90))
			_spawn_enemy("ant", Vector2(2860, 220))
			_spawn_enemy("goblin", Vector2(3650, 120))
			_spawn_enemy("beetle", Vector2(4450, 120))
			_spawn_enemy("slime", Vector2(5250, 200))
			_spawn_enemy("goblin", Vector2(6200, 120))
			_spawn_enemy("beetle", Vector2(7300, 200))
			_spawn_chest(Vector2(1320, 100))
			_spawn_chest(Vector2(3000, 120))
			_spawn_chest(Vector2(5680, 120))
			_spawn_candle(Vector2(300, 130))
			_spawn_candle(Vector2(2940, 100))
			_spawn_candle(Vector2(6850, 200))
		12:
			_spawn_enemy("slime", Vector2(450, 270))
			_spawn_enemy("ant", Vector2(850, 110))
			_spawn_enemy("goblin", Vector2(1340, 260))
			_spawn_enemy("beetle", Vector2(2400, 240))
			_spawn_enemy("slime", Vector2(2940, 100))
			_spawn_enemy("goblin", Vector2(3700, 240))
			_spawn_enemy("ant", Vector2(4560, 240))
			_spawn_enemy("beetle", Vector2(5320, 120))
			_spawn_enemy("slime", Vector2(6150, 240))
			_spawn_enemy("goblin", Vector2(7000, 100))
			_spawn_chest(Vector2(1460, 110))
			_spawn_chest(Vector2(3320, 90))
			_spawn_chest(Vector2(5700, 250))
			_spawn_candle(Vector2(150, 130))
			_spawn_candle(Vector2(4040, 240))
			_spawn_candle(Vector2(7420, 100))

func _spawn_enemy(kind: String, spawn_position: Vector2) -> void:
	var path: String = ENEMIES.get(kind, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var enemy: Node2D = load(path).instantiate()
	enemy.position = spawn_position
	add_child(enemy)

func _spawn_chest(spawn_position: Vector2) -> void:
	var chest := preload("res://chest.tscn").instantiate()
	chest.position = spawn_position
	add_child(chest)

func _spawn_candle(spawn_position: Vector2) -> void:
	var candle := preload("res://candle.tscn").instantiate()
	candle.position = spawn_position
	add_child(candle)

func _build_exit() -> void:
	var exit := Area2D.new()
	exit.name = "nextlevel"
	exit.collision_layer = 0
	exit.collision_mask = 1
	exit.set_script(preload("res://scenes/nextlevel.gd"))
	exit.set("next_scene", "res://scenes/level_%02d.tscn" % (level_id + 1) if level_id < 12 else "res://scenes/map.tscn")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(180, 500)
	shape.shape = rectangle
	var exit_x := 7060.0 if level_id == 10 else (7280.0 if level_id == 11 else 7160.0)
	shape.position = Vector2(exit_x, 100)
	exit.add_child(shape)
	add_child(exit)

func _draw() -> void:
	# Chunky hand-drawn cave blocks keep the bonus rooms readable without
	# introducing a second visual language or another tileset.
	for rect in platforms:
		# A small highlight line keeps the tile-built ledges readable at a glance.
		draw_line(rect.position + Vector2(0, 4), rect.position + Vector2(rect.size.x, 4), accent, 3.0)
	for x in range(-400, 8500, 260):
		var y := -80.0 + fmod(abs(float(x * 7 + level_id * 91)), 150.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y), Vector2(x + 34, y), Vector2(x + 17, y + 52),
		]), Color(0.12, 0.07, 0.13, 0.9))
		if level_id == 10:
			draw_circle(Vector2(x + 17, y + 66), 7.0, Color(0.35, 0.9, 1.0, 0.85))
		elif level_id == 11:
			draw_circle(Vector2(x + 17, y + 66), 7.0, Color(1.0, 0.45, 0.22, 0.8))
		else:
			draw_circle(Vector2(x + 17, y + 66), 7.0, Color(1.0, 0.85, 0.25, 0.8))
