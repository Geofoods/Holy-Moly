extends RigidBody2D

## Shared base for the player's custom throwable bombs (Golden Bomb, Spark Bomb,
## Mine, Stink Bomb, Flare...). Thrown like a normal bomb, then _blast() is called
## on detonation. Subclasses set their own visuals/parameters and only need to
## override _blast().

const FUSE_TIME := 2.2
const FLASH_TIME := 0.35
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

var accent := Color(1.0, 1.0, 1.0, 1.0)
var blast_radius := 160.0
var enemy_damage := 4.0
var self_damage := 2.0
var hits_mole := true
var tile_break_radius := 1

var dead := false
var fuse_active := false
var fuse_elapsed := 0.0
var tick_cooldown := 0.0
var is_flashing := false

var _sprite: Sprite2D

func _build_visual() -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = preload("res://scenes/bomb.webp")
	spr.scale = Vector2(0.25, 0.25)
	spr.z_index = 1
	spr.modulate = accent
	add_child(spr)
	return spr

func _ready() -> void:
	linear_velocity = Vector2.ZERO
	_sprite = _build_visual()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 38.6
	shape.shape = circle
	shape.position = Vector2(4, -4)
	add_child(shape)
	collision_layer = 1
	collision_mask = 1

func _process(delta: float) -> void:
	if not fuse_active or is_flashing:
		return
	fuse_elapsed += delta
	var progress := clampf(fuse_elapsed / (FUSE_TIME - FLASH_TIME), 0.0, 1.0)
	tick_cooldown -= delta
	if tick_cooldown <= 0.0:
		SFX.play("bomb_tick", global_position, -4.0, 0.05)
		tick_cooldown = lerpf(0.5, 0.1, progress)
	var pulse := 0.5 + sin(fuse_elapsed * lerpf(8.0, 25.0, progress)) * 0.5
	var intensity := lerpf(0.4, 1.4, progress) + pulse * 0.3
	if _sprite:
		_sprite.modulate = Color(accent.r * intensity, accent.g * intensity, accent.b * intensity, 1.0)
	if fuse_elapsed >= FUSE_TIME - FLASH_TIME:
		_start_flash()

func arm() -> void:
	fuse_active = true

func _start_flash() -> void:
	is_flashing = true
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(8.0, 8.0, 8.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)
	tween.tween_property(_sprite, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.06).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	tween.parallel().tween_property(self, "scale", Vector2(1.4, 1.4), FLASH_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_explode)

func _explode() -> void:
	if dead:
		return
	dead = true
	SFX.play("explosion", global_position)
	_blast()
	_blast_particles()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(16.0, 0.3)
	if hits_mole and mole and is_instance_valid(mole):
		var dist := global_position.distance_to(mole.global_position)
		if dist <= blast_radius and mole.has_method("take_damage"):
			mole.take_damage(self_damage, global_position, true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)

func _blast() -> void:
	pass

func _damage_enemies_in_radius() -> void:
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= blast_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(enemy_damage)
			elif enemy.has_method("die"):
				enemy.die()

func _break_tiles_in_radius() -> void:
	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if not tilemap:
		return
	var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
	for dx in range(-tile_break_radius, tile_break_radius + 1):
		for dy in range(-tile_break_radius, tile_break_radius + 1):
			var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
			if tilemap.get_cell_source_id(0, tp) != -1:
				TileBreakSFX.break_tile(tilemap, tp, get_parent())
			elif tilemap.get_cell_source_id(1, tp) != -1:
				TileBreakSFX.break_decoration_tile(tilemap, tp, get_parent())
	TileBreakSFX.break_opened_chests_near(get_parent(), global_position, blast_radius)

func _blast_particles() -> void:
	var smoke := CPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 40
	smoke.lifetime = 0.5
	smoke.explosiveness = 0.9
	smoke.direction = Vector2.ZERO
	smoke.spread = 180.0
	smoke.initial_velocity_min = blast_radius * 1.5
	smoke.initial_velocity_max = blast_radius * 2.5
	smoke.damping_min = blast_radius * 2.5
	smoke.damping_max = blast_radius * 3.5
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