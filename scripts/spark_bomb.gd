extends "res://scripts/custom_bomb.gd"

## Spark Bomb: on detonation it zaps the nearest enemy in range with chain
## lightning that then arcs to up to CHAIN_JUMP-1 other nearby enemies.

const CHAIN_JUMP := 4
const CHAIN_RANGE := 200.0

var _already_hit: Array = []

func _init() -> void:
	accent = Color(0.55, 0.7, 1.2, 1.0)
	blast_radius = 260.0
	enemy_damage = 6.0
	self_damage = 0.0
	hits_mole = false

func _blast() -> void:
	var pool: Array = []
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= blast_radius:
			pool.append(enemy)

	var origin := global_position
	var jumps_left := CHAIN_JUMP
	while not pool.is_empty() and jumps_left > 0:
		var nearest: Node2D = null
		var nearest_dist := INF
		for enemy in pool:
			if enemy in _already_hit:
				continue
			var d := origin.distance_to(enemy.global_position)
			if d < nearest_dist:
				nearest = enemy
				nearest_dist = d
		if nearest == null:
			break
		if nearest_dist > CHAIN_RANGE and not _already_hit.is_empty():
			break
		_already_hit.append(nearest)
		_draw_bolt(origin, nearest.global_position)
		if nearest.has_method("take_damage"):
			nearest.take_damage(_rolled_enemy_damage())
			SFX.play("enemy_hit", nearest.global_position)
		origin = nearest.global_position
		jumps_left -= 1

func _draw_bolt(from: Vector2, to: Vector2) -> void:
	var bolt := Line2D.new()
	bolt.width = 4.0
	bolt.default_color = Color(0.7, 0.85, 1.3, 1.0)
	bolt.z_index = 12
	var mid := (from + to) * 0.5
	mid += Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	bolt.points = PackedVector2Array([from, mid, to])
	get_parent().add_child(bolt)
	var tw := create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.25)
	tw.tween_callback(bolt.queue_free)

	var spark := CPUParticles2D.new()
	spark.emitting = true
	spark.one_shot = true
	spark.amount = 12
	spark.lifetime = 0.3
	spark.explosiveness = 1.0
	spark.direction = Vector2.ZERO
	spark.spread = 180.0
	spark.initial_velocity_min = 60.0
	spark.initial_velocity_max = 180.0
	spark.scale_amount_min = 3.0
	spark.scale_amount_max = 6.0
	spark.color = Color(0.7, 0.85, 1.3, 1.0)
	spark.z_index = 12
	get_parent().add_child(spark)
	spark.global_position = to
	get_tree().create_timer(0.5).timeout.connect(spark.queue_free)