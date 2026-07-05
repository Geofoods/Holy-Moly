extends Area2D

const DRILL_DURATION := 1.0
const SPEED := 1000.0

var velocity := Vector2.ZERO
var elapsed := 0.0
var prev_tile_pos := Vector2i(999999, 999999)

var _drill_player: AudioStreamPlayer2D = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_start_drill_sound()

func _start_drill_sound() -> void:
	if not SFX._sounds.has("drill") or SFX._sounds["drill"].size() == 0:
		return
	_drill_player = AudioStreamPlayer2D.new()
	_drill_player.stream = SFX._sounds["drill"][0]
	_drill_player.volume_db = -8.0
	_drill_player.max_distance = 2000.0
	add_child(_drill_player)
	_drill_player.play()

func setup(dir: Vector2) -> void:
	velocity = dir * SPEED
	rotation = velocity.angle() + PI / 2

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := area.get_parent()
	if enemy and is_instance_valid(enemy):
		if enemy.has_method("take_damage"):
			enemy.take_damage(3)
		elif enemy.has_method("die"):
			enemy.die()

func _process(delta: float) -> void:
	elapsed += delta

	global_position += velocity * delta

	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if not tilemap:
		if elapsed >= DRILL_DURATION:
			queue_free()
		return

	var sfx = load("res://scripts/tile_break_sfx.gd")

	const BREAK_SCALE := 2.0

	var polygons: Array[PackedVector2Array] = []
	for child in get_children():
		if child is CollisionPolygon2D:
			var scaled := PackedVector2Array()
			for p in child.polygon:
				scaled.append(p * BREAK_SCALE)
			polygons.append(scaled)

	var tiles: Array[Vector2i] = []
	for polygon in polygons:
		var global_poly := PackedVector2Array()
		for p in polygon:
			global_poly.append(to_global(p))

		var min_x := INF
		var min_y := INF
		var max_x := -INF
		var max_y := -INF
		for p in global_poly:
			if p.x < min_x: min_x = p.x
			if p.y < min_y: min_y = p.y
			if p.x > max_x: max_x = p.x
			if p.y > max_y: max_y = p.y

		var top_left := tilemap.local_to_map(tilemap.to_local(Vector2(min_x, min_y)))
		var bottom_right := tilemap.local_to_map(tilemap.to_local(Vector2(max_x, max_y)))

		for x in range(top_left.x, bottom_right.x + 1):
			for y in range(top_left.y, bottom_right.y + 1):
				var tile_pos := Vector2i(x, y)
				if tile_pos not in tiles:
					var center := tilemap.to_global(tilemap.map_to_local(tile_pos))
					if Geometry2D.is_point_in_polygon(center, global_poly):
						tiles.append(tile_pos)

	for tile_pos in tiles:
		if tile_pos != prev_tile_pos:
			var has_collision := tilemap.get_cell_source_id(0, tile_pos) != -1
			if has_collision:
				sfx.break_tile(tilemap, tile_pos, get_parent())
			else:
				sfx.break_decoration_tile(tilemap, tile_pos, get_parent())
			prev_tile_pos = tile_pos

	if elapsed >= DRILL_DURATION:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
