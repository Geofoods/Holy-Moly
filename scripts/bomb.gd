extends RigidBody2D

const FUSE_TIME := 2.5
const FLASH_TIME := 0.4
const ENEMY_DAMAGE := 5.0
const DAMAGE_SCALAR := 10.0
const DAMAGE_VARIATION := 0.2
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

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

	tick_cooldown -= delta
	if tick_cooldown <= 0.0:
		SFX.play("bomb_tick", global_position, -4.0, 0.05)
		var interval := lerpf(0.5, 0.1, progress)
		tick_cooldown = interval

	var pulse_speed := lerpf(8.0, 25.0, progress)
	var pulse := 0.5 + sin(fuse_elapsed * pulse_speed) * 0.5
	var red_intensity := lerpf(0.3, 1.0, progress)
	sprite.modulate = Color(1.0, 1.0 - red_intensity * 0.5 + pulse * 0.2, 1.0 - red_intensity * 0.7 + pulse * 0.1, 1.0)

	if fuse_elapsed >= FUSE_TIME - FLASH_TIME:
		_start_flash()

func arm() -> void:
	fuse_active = true

func _start_flash() -> void:
	is_flashing = true
	var tween := create_tween()
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
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(20.0, 0.35)
	if mole and is_instance_valid(mole):
		var dist := global_position.distance_to(mole.global_position)
		if dist <= explosion_radius and mole.has_method("take_damage"):
			mole.take_damage(explosion_damage, global_position, true)

	var smoke := CPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 40
	smoke.lifetime = 0.5
	smoke.explosiveness = 0.9
	smoke.direction = Vector2.ZERO
	smoke.spread = 180.0
	smoke.initial_velocity_min = explosion_radius * 1.5
	smoke.initial_velocity_max = explosion_radius * 2.5
	smoke.damping_min = explosion_radius * 2.5
	smoke.damping_max = explosion_radius * 3.5
	smoke.scale_amount_min = 10.0
	smoke.scale_amount_max = 20.0
	smoke.color = Color(0.2, 0.2, 0.2, 0.9)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.2, 0.2, 0.2, 0.9))
	fade.set_color(1, Color(0.1, 0.1, 0.1, 0.0))
	smoke.color_ramp = fade
	get_parent().add_child(smoke)
	smoke.global_position = global_position
	get_tree().create_timer(1.0).timeout.connect(smoke.queue_free)

	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if tilemap:
		var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
		for dx in range(-tile_break_radius, tile_break_radius + 1):
			for dy in range(-tile_break_radius, tile_break_radius + 1):
				var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
				if tilemap.get_cell_source_id(0, tp) != -1:
					TileBreakSFX.break_tile(tilemap, tp, get_parent())
				elif tilemap.get_layers_count() > 1 and tilemap.get_cell_source_id(1, tp) != -1:
					TileBreakSFX.break_decoration_tile(tilemap, tp, get_parent())
		TileBreakSFX.break_opened_chests_near(get_parent(), global_position, explosion_radius)

	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				var dmg := ENEMY_DAMAGE * DAMAGE_SCALAR * ComboManager.get_damage_multiplier() * randf_range(1.0 - DAMAGE_VARIATION, 1.0 + DAMAGE_VARIATION)
				enemy.take_damage(dmg)
			elif enemy.has_method("die"):
				enemy.die()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
