extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var fuse_timer: Timer = $FuseTimer
@onready var explosion_area: Area2D = $ExplosionArea

func _ready() -> void:
	fuse_timer.timeout.connect(_on_fuse_timeout)
	fuse_timer.start()

func _on_fuse_timeout() -> void:
	sprite.visible = false

	var explosion := CPUParticles2D.new()
	explosion.emitting = true
	explosion.one_shot = true
	explosion.amount = 40
	explosion.lifetime = 0.6
	explosion.explosiveness = 1.0
	explosion.direction = Vector2.ZERO
	explosion.spread = 360.0
	explosion.initial_velocity_min = 200.0
	explosion.initial_velocity_max = 500.0
	explosion.gravity = Vector2.ZERO
	explosion.damping_min = 30.0
	explosion.damping_max = 80.0
	explosion.scale_amount_min = 3.0
	explosion.scale_amount_max = 6.0
	explosion.color = Color(1.0, 0.6, 0.1, 1.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.7, 0.15, 1.0))
	fade.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
	explosion.color_ramp = fade
	get_parent().add_child(explosion)
	explosion.global_position = global_position

	explosion_area.monitoring = true
	await get_tree().physics_frame

	for area in explosion_area.get_overlapping_areas():
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy and enemy.has_method("die"):
				enemy.die()

	_break_tiles()

	get_tree().create_timer(0.6).timeout.connect(queue_free)
	get_tree().create_timer(1.0).timeout.connect(explosion.queue_free)

func _break_tiles() -> void:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if not tilemap:
		return
	var center := tilemap.local_to_map(tilemap.to_local(global_position))
	var radius_tiles := 2
	var sfx = load("res://scripts/tile_break_sfx.gd")
	for x in range(-radius_tiles, radius_tiles + 1):
		for y in range(-radius_tiles, radius_tiles + 1):
			if Vector2i(x, y).length() > radius_tiles:
				continue
			var tile_pos := center + Vector2i(x, y)
			if tilemap.get_cell_source_id(0, tile_pos) != -1:
				sfx.break_tile(tilemap, tile_pos, get_parent())
