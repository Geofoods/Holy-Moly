extends RigidBody2D

const FUSE_TIME := 2.5
const FLASH_TIME := 0.4

@export var explosion_radius := 200.0
@export var explosion_damage := 2.0
@export var tile_break_radius := 2

var dead := false
var fuse_active := false
var fuse_elapsed := 0.0
var tick_cooldown := 0.0
var is_flashing := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	linear_velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if not fuse_active or is_flashing:
		return
	fuse_elapsed += delta

	var progress := clampf(fuse_elapsed / (FUSE_TIME - FLASH_TIME), 0.0, 1.0)

	# Ticking sound that speeds up as fuse runs out
	tick_cooldown -= delta
	if tick_cooldown <= 0.0:
		SFX.play("bomb_tick", global_position, -4.0, 0.05)
		var interval := lerpf(0.5, 0.1, progress)
		tick_cooldown = interval

	# Pulsing red tint that intensifies over time
	var pulse_speed := lerpf(8.0, 25.0, progress)
	var pulse := 0.5 + sin(fuse_elapsed * pulse_speed) * 0.5
	var red_intensity := lerpf(0.3, 1.0, progress)
	sprite.modulate = Color(1.0, 1.0 - red_intensity * 0.5 + pulse * 0.2, 1.0 - red_intensity * 0.7 + pulse * 0.1, 1.0)

	# Start the flash phase before explosion
	if fuse_elapsed >= FUSE_TIME - FLASH_TIME:
		_start_flash()

func arm() -> void:
	fuse_active = true

func _start_flash() -> void:
	is_flashing = true
	var tween := create_tween()
	# Minecraft-style: flash white and enlarge briefly
	tween.tween_property(sprite, "modulate", Color(8.0, 8.0, 8.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.06).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(12.0, 12.0, 12.0, 1.0), 0.05).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), FLASH_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_explode)

func _explode() -> void:
	if dead:
		return
	dead = true
	SFX.play("explosion", global_position)

	var explosion_particles := preload("res://Retro Explosion.tscn").instantiate()
	explosion_particles.global_position = global_position
	get_parent().add_child(explosion_particles)
	explosion_particles.emitting = true

	var mole := get_tree().get_first_node_in_group("mole")
	if mole and is_instance_valid(mole):
		var dist := global_position.distance_to(mole.global_position)
		if dist <= explosion_radius and mole.has_method("take_damage"):
			mole.take_damage(explosion_damage, global_position, true)

	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if tilemap:
		var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
		var sfx = load("res://scripts/tile_break_sfx.gd")
		for dx in range(-tile_break_radius, tile_break_radius + 1):
			for dy in range(-tile_break_radius, tile_break_radius + 1):
				var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
				var has_collision := tilemap.get_cell_source_id(0, tp) != -1
				if has_collision:
					sfx.break_tile(tilemap, tp, get_parent())
				else:
					sfx.break_decoration_tile(tilemap, tp, get_parent())

	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(5)
			elif enemy.has_method("die"):
				enemy.die()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
