extends "res://scripts/bomb.gd"

## An ice variant of the Bomb. Same fuse and throw, but instead of a fiery
## blast it detonates with a cold snap that freezes every enemy in its blast
## radius solid for FREEZE_DURATION seconds. Caught in it yourself? You freeze
## for a brief moment too.

const FREEZE_DURATION := 5.0
const MOLE_FREEZE_DURATION := 2.0

func _process(delta: float) -> void:
	if not fuse_active or is_flashing:
		return
	fuse_elapsed += delta

	var progress := clampf(fuse_elapsed / (FUSE_TIME - FLASH_TIME), 0.0, 1.0)

	tick_cooldown -= delta
	if tick_cooldown <= 0.0:
		SFX.play("bomb_tick", global_position, -8.0, 0.05)
		var interval := lerpf(0.5, 0.1, progress)
		tick_cooldown = interval

	var pulse_speed := lerpf(8.0, 25.0, progress)
	var pulse := 0.5 + sin(fuse_elapsed * pulse_speed) * 0.5
	sprite.modulate = Color(0.55 + pulse * 0.2, 0.8 + pulse * 0.1, 1.1 + pulse * 0.3, 1.0)

	if fuse_elapsed >= FUSE_TIME - FLASH_TIME:
		_start_flash()

func _start_flash() -> void:
	is_flashing = true
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(8.0, 9.0, 13.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "modulate", Color(0.8, 0.9, 1.0, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color(9.0, 10.0, 15.0, 1.0), 0.06).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "modulate", Color(1.5, 1.8, 2.8, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(11.0, 12.0, 17.0, 1.0), 0.05).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), FLASH_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_explode)

func _explode() -> void:
	if dead:
		return
	dead = true
	SFX.play("explosion", global_position)

	_spawn_ice_burst()
	_freeze_radius()

	var mole := get_tree().get_first_node_in_group("mole")
	if mole and mole.has_method("screen_shake"):
		mole.screen_shake(14.0, 0.3)
	if mole:
		var dist := global_position.distance_to(mole.global_position)
		if dist <= explosion_radius:
			freeze_node(mole, MOLE_FREEZE_DURATION)

	var tilemap: TileMap = get_parent().get_node_or_null("TileMap")
	if tilemap:
		_freeze_tiles(tilemap)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)

## Breaks the stuff tiles in the blast radius (decorations and tiles flagged
## as stuff) and coats the remaining normal tiles in ice instead of destroying
## them.
func _freeze_tiles(tilemap: TileMap) -> void:
	var center_tile := tilemap.local_to_map(tilemap.to_local(global_position))
	var tile_world_size := Vector2(tilemap.tile_set.tile_size) * tilemap.scale
	var half := tile_world_size * 0.5

	var frost_layer := Node2D.new()
	frost_layer.name = "FrostOverlay"
	frost_layer.z_index = 0
	frost_layer.global_position = Vector2.ZERO
	get_parent().add_child(frost_layer)

	for dx in range(-tile_break_radius, tile_break_radius + 1):
		for dy in range(-tile_break_radius, tile_break_radius + 1):
			var tp := Vector2i(center_tile.x + dx, center_tile.y + dy)
			var cell_data := tilemap.get_cell_tile_data(0, tp)
			var has_decoration := tilemap.get_cell_source_id(1, tp) != -1
			var is_stuff := cell_data != null and (cell_data.get_custom_data("stuff") as bool)

			if is_stuff:
				TileBreakSFX.break_tile(tilemap, tp, get_parent())
				continue

			if has_decoration:
				TileBreakSFX.break_decoration_tile(tilemap, tp, get_parent())

			if tilemap.get_cell_source_id(0, tp) == -1:
				continue
			var rect := ColorRect.new()
			rect.position = tilemap.to_global(tilemap.map_to_local(tp)) - half
			rect.size = tile_world_size
			rect.modulate = Color(0.55, 0.83, 1.15, randf_range(0.28, 0.42))
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frost_layer.add_child(rect)
	if frost_layer.get_child_count() > 0:
		get_tree().create_timer(6.0).timeout.connect(frost_layer.queue_free)
	else:
		frost_layer.queue_free()

func _spawn_ice_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 46
	burst.lifetime = 0.55
	burst.explosiveness = 0.9
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = explosion_radius * 1.5
	burst.initial_velocity_max = explosion_radius * 2.5
	burst.damping_min = explosion_radius * 2.5
	burst.damping_max = explosion_radius * 3.5
	burst.scale_amount_min = 9.0
	burst.scale_amount_max = 16.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.92, 1.0, 0.95))
	fade.set_color(1, Color(0.5, 0.7, 1.0, 0.0))
	burst.color_ramp = fade
	get_parent().add_child(burst)
	burst.global_position = global_position

	var shards := CPUParticles2D.new()
	shards.emitting = true
	shards.one_shot = true
	shards.amount = 18
	shards.lifetime = 0.7
	shards.explosiveness = 0.0
	shards.direction = Vector2.ZERO
	shards.spread = 180.0
	shards.initial_velocity_min = 120.0
	shards.initial_velocity_max = 260.0
	shards.gravity = Vector2(0, 500)
	shards.scale_amount_min = 4.0
	shards.scale_amount_max = 8.0
	shards.color = Color(0.9, 0.95, 1.0, 1.0)
	get_parent().add_child(shards)
	shards.global_position = global_position

	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)
	get_tree().create_timer(1.2).timeout.connect(shards.queue_free)

func _freeze_radius() -> void:
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not is_instance_valid(hurtbox):
			continue
		var enemy := hurtbox.get_parent()
		if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= explosion_radius:
			freeze_node(enemy, FREEZE_DURATION)

	for bullet in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(bullet):
			continue
		if bullet.get("deflected") == true:
			continue
		if global_position.distance_to(bullet.global_position) <= explosion_radius:
			freeze_node(bullet, FREEZE_DURATION)

func freeze_node(node: Node2D, duration: float) -> void:
	if node == null or not is_instance_valid(node) or node.has_meta("frozen"):
		return
	node.set_meta("frozen", true)
	node.set_meta("freeze_restore_physics", node.is_physics_processing())
	node.set_meta("freeze_restore_process", node.is_processing())
	node.set_meta("freeze_restore_modulate", node.modulate)
	if node is Area2D:
		node.set_meta("freeze_restore_monitoring", node.get("monitoring"))
		node.set("monitoring", false)
	if node is CharacterBody2D:
		node.set("velocity", Vector2.ZERO)
	node.modulate = Color(0.55, 0.82, 1.2, 0.9)
	node.set_physics_process(false)
	node.set_process(false)
	node.get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(node):
			node.set_physics_process(node.get_meta("freeze_restore_physics", true))
			node.set_process(node.get_meta("freeze_restore_process", true))
			if node is Area2D:
				node.set("monitoring", node.get_meta("freeze_restore_monitoring", true))
			node.modulate = node.get_meta("freeze_restore_modulate", Color.WHITE)
			node.remove_meta("frozen")
	)
