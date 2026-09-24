extends CharacterBody2D

signal died

const SPEED = 160.0
const CLIMB_SPEED = 140.0
const GRAVITY = 1960.0
const CLIMB_DURATION = 0.6
const DETECT_RANGE := 300.0
const CLIMB_CHANCE = 0.4
const MAX_HEALTH := 30.0
const SHOOT_INTERVAL := 5.0

var direction := 1.0
var target_mole: Node2D = null
var is_climbing := false
var climb_timer := 0.0
var health := MAX_HEALTH
## Direction the last hit pushed this enemy (attacker -> enemy). Its death
## fragments are blown that way so they read as the blow that killed it.
var hit_direction := Vector2.ZERO
var _move_sfx_timer := 0.0
var _shoot_timer := SHOOT_INTERVAL
var _stun_timer := 0.0
var _slow_timer := 0.0
var _slow_factor := 1.0
const MOVE_SFX_INTERVAL := 0.4

## Level-of-detail throttling: enemies far from the mole don't need 60Hz AI.
const FAR_UPDATE_INTERVAL := 0.1
## Past this distance enemies only tick at FAR_UPDATE_INTERVAL.
const FAR_UPDATE_DIST := 1200.0
const FAR_UPDATE_DIST_SQ := FAR_UPDATE_DIST * FAR_UPDATE_DIST
## Beyond this distance the enemy fully sleeps (it can't see or reach the mole).
const SLEEP_DIST := 2600.0
var ant_bullet_scene := preload("res://scenes/ant_bullet.tscn")
var _mole_in_contact := false
var _mole: Node2D = null
var _target_scan_timer := 0.0
var _lod_timer := 0.0
var _far_mode := false
var _asleep := false
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: AnimatedSprite2D = $Visual
var _health_bar: Node2D = null

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.z_index = 1
	visual.play()
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	# --- Distance LOD: far enemies tick at 10Hz, very far ones sleep ---
	var lod_tick := false
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = FAR_UPDATE_INTERVAL
		lod_tick = true
		var mole := _get_mole()
		if mole != null:
			var dist_sq := global_position.distance_squared_to(mole.global_position)
			_far_mode = dist_sq > FAR_UPDATE_DIST_SQ
			_asleep = dist_sq > SLEEP_DIST * SLEEP_DIST
		else:
			_far_mode = false
			_asleep = false
	if _asleep:
		return
	if _far_mode and not lod_tick:
		return

	_target_scan_timer -= delta
	if _target_scan_timer <= 0.0:
		_target_scan_timer = 0.2
		_find_target()

	if _stun_timer > 0.0:
		_stun_timer -= delta
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		_update_visual_direction()
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_factor = 1.0
			if not has_meta("frozen"):
				modulate = Color.WHITE

	if is_climbing:
		climb_timer -= delta
		velocity.y = -CLIMB_SPEED
		velocity.x = direction * SPEED * 0.3 * _slow_factor
		if climb_timer <= 0.0 or is_on_ceiling():
			is_climbing = false
		move_and_slide()
		_update_visual_direction()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * SPEED * _slow_factor

	if is_on_wall():
		if randf() < CLIMB_CHANCE:
			is_climbing = true
			climb_timer = CLIMB_DURATION
		else:
			direction *= -1

	move_and_slide()
	_update_visual_direction()
	_play_move_sound(delta)
	_update_shooting(delta)

func _get_mole() -> Node2D:
	if _mole != null and not is_instance_valid(_mole):
		_mole = null
	if _mole == null:
		_mole = get_tree().get_first_node_in_group("mole")
	return _mole

func _update_shooting(delta: float) -> void:
	if health <= 0:
		return
	var mole := _get_mole()
	if not mole:
		return
	var dist := global_position.distance_to(mole.global_position)
	if dist > 1000.0 or dist < 120.0:
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = SHOOT_INTERVAL
		_shoot_bullet(mole)

func _shoot_bullet(target: Node2D) -> void:
	SFX.play("enemy_fire", global_position, -4.0, 0.2)
	SFX.play("parry_activate", global_position, -14.0, 0.6)
	var bullet = ant_bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(0, -20)
	bullet.direction = (target.global_position - global_position).normalized()
	bullet.source_ant = self

func _play_move_sound(delta: float) -> void:
	if health <= 0 or velocity.x == 0.0:
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer <= 0.0:
		_move_sfx_timer = MOVE_SFX_INTERVAL
		SFX.play("land", global_position, -18.0, 0.4)

func _update_visual_direction() -> void:
	var dir = sign(velocity.x) if velocity.x != 0.0 else direction
	visual.scale.x = -abs(visual.scale.x) * sign(dir)

func _find_target() -> void:
	var lure := _find_lure()
	if lure:
		target_mole = lure
		return
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = _get_mole()
		if target_mole:
			add_collision_exception_with(target_mole)
	elif global_position.distance_squared_to(target_mole.global_position) > DETECT_RANGE * DETECT_RANGE:
		target_mole = null

func _find_lure() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for lure in get_tree().get_nodes_in_group("lure"):
		if not is_instance_valid(lure):
			continue
		var d := global_position.distance_squared_to(lure.global_position)
		if d < DETECT_RANGE * DETECT_RANGE and d < best_dist:
			best = lure
			best_dist = d
	return best

func apply_slow(duration: float, factor: float) -> void:
	if health <= 0:
		return
	_slow_timer = maxf(_slow_timer, duration)
	_slow_factor = minf(_slow_factor, clampf(factor, 0.05, 1.0))
	if not has_meta("frozen"):
		modulate = Color(0.6, 0.9, 0.55, 1.0)

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and not _mole_in_contact:
		_mole_in_contact = true
		body.take_damage(1, global_position, true)

func _on_hitbox_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_in_contact = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == hitbox or not area.monitoring:
		return
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		var swing_dir := Vector2.ZERO
		var mole = get_tree().get_first_node_in_group("mole")
		if mole:
			swing_dir = (global_position - mole.global_position).normalized()
			velocity = swing_dir * 600.0 + Vector2(0, -250)
			_stun_timer = 0.25
		take_damage(parent.get_damage(), swing_dir)

func take_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if hit_dir != Vector2.ZERO:
		hit_direction = hit_dir.normalized()
	if health <= 0:
		return
	health -= amount
	spawn_damage_number(self, amount)
	SFX.play("enemy_hit", global_position)
	if _health_bar:
		_health_bar.queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2, 1, 1, 1), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if health <= 0:
		die()

class FloatingDamageLabel:
	extends Label

	const GRAVITY := 700.0
	const LIFETIME := 0.8

	var velocity := Vector2.ZERO
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		velocity.y += GRAVITY * delta
		position += velocity * delta
		modulate.a = clampf(1.0 - _time / LIFETIME, 0.0, 1.0)
		if _time >= LIFETIME:
			queue_free()

static var _damage_font: Font = null

static func spawn_damage_number(enemy: Node2D, amount: float, origin: Vector2 = Vector2.INF) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var current := enemy.get_tree().current_scene
	if not current:
		return

	var label := FloatingDamageLabel.new()
	label.text = str(int(round(amount)))
	label.add_theme_font_size_override("font_size", 90)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	if _damage_font == null:
		_damage_font = load("res://Baby Doll.otf") as Font
	if _damage_font:
		label.add_theme_font_override("font", _damage_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 50
	label.velocity = Vector2.from_angle(randf_range(-PI * 0.78, -PI * 0.22)) * randf_range(880.0, 960.0)
	label.scale = Vector2(0.6, 0.6)
	current.add_child(label)
	var start := enemy.global_position
	if origin != Vector2.INF:
		start = origin
	label.global_position = start + Vector2(randf_range(-16.0, 16.0), randf_range(-28.0, -6.0))

	var pop := label.create_tween()
	pop.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _setup_health_bar() -> void:
	_health_bar = Node2D.new()
	_health_bar.name = "HealthBar"
	_health_bar.z_index = 10
	_health_bar.draw.connect(_draw_health_bar)
	add_child(_health_bar)

func _draw_health_bar() -> void:
	if health <= 0 or health >= MAX_HEALTH:
		return
	if not is_instance_valid(_health_bar):
		return
	var bar_w := 96.0
	var bar_h := 12.0
	var offset := Vector2(-bar_w / 2, -100)
	var ratio := health / MAX_HEALTH

	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(1.0 * (1.0 - ratio) + 0.2 * ratio, 0.2 * (1.0 - ratio) + 0.8 * ratio, 0.2, 0.95)
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	died.emit()
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	Shop.drop_coins(global_position, randi_range(2, 4))
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

## Fragments are the pieces an enemy breaks into when it dies. They are real
## rigid bodies, so they tumble, bounce off the terrain and settle, and they are
## flung away from the blow that landed rather than in an even ring.
const FRAGMENT_COLS := 4
const FRAGMENT_ROWS := 2
## Debris layer, shared with the chunks tile breaking leaves behind.
const FRAGMENT_LAYER := 2
## Fragments collide with the terrain only - never with enemies or each other.
const FRAGMENT_WORLD_LAYER := 1
const FRAGMENT_SPEED_MIN := 180.0
const FRAGMENT_SPEED_MAX := 420.0
## How far a fragment may stray from the blow direction, in radians.
const FRAGMENT_SPREAD := 0.9
## Upward kick, so the burst arcs instead of skidding along the floor.
const FRAGMENT_LIFT := 220.0
const FRAGMENT_LINGER := 0.55
const FRAGMENT_FADE := 0.35

func _break_apart() -> void:
	spawn_death_fragments(self, visual, hit_direction, scale.x)

## Cuts `visual`'s current frame into a grid of gibs and throws them into the
## level as rigid bodies, blown away from `hit_dir` (defaults to away from the
## mole). `visual` can be either an AnimatedSprite2D or a plain Sprite2D.
static func spawn_death_fragments(enemy: Node2D, visual: Node2D, hit_dir := Vector2.ZERO, pop_scale := 1.0) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(visual):
		return
	var parent := enemy.get_parent()
	if parent == null:
		return

	var source_tex: Texture2D = null
	var source_region := Rect2()
	var visual_scale := Vector2.ONE
	var visual_offset := Vector2.ZERO
	var flipped := false

	if visual is AnimatedSprite2D:
		var animated := visual as AnimatedSprite2D
		visual_scale = animated.scale
		visual_offset = animated.position
		flipped = animated.flip_h
		var frame_tex := animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if frame_tex == null:
			return
		var atlas := frame_tex as AtlasTexture
		source_tex = atlas.atlas if atlas else frame_tex
		source_region = atlas.region if atlas else Rect2(Vector2.ZERO, frame_tex.get_size())
	elif visual is Sprite2D:
		var plain := visual as Sprite2D
		visual_scale = plain.scale
		visual_offset = plain.position
		flipped = plain.flip_h
		source_tex = plain.texture
		if source_tex == null:
			return
		source_region = plain.region_rect if plain.region_enabled else Rect2(Vector2.ZERO, source_tex.get_size())
	else:
		return

	if source_region.size.x <= 0.0 or source_region.size.y <= 0.0:
		return
	visual.visible = false

	var piece_size := Vector2(source_region.size.x / FRAGMENT_COLS, source_region.size.y / FRAGMENT_ROWS)
	var center_offset := source_region.size * 0.5
	var blast_angle := _fragment_blast_direction(enemy, hit_dir).angle()
	# die() pops the enemy up in scale just before it bursts, and the pieces are
	# spawned in the level instead of on the enemy, so bake that pop in by hand.
	var exit_scale := maxf(pop_scale, 0.0)
	var piece_scale := visual_scale * exit_scale * 0.5

	for col in FRAGMENT_COLS:
		for row in FRAGMENT_ROWS:
			var offset := Vector2(col * piece_size.x + piece_size.x * 0.5, row * piece_size.y + piece_size.y * 0.5) - center_offset
			if flipped:
				offset.x = -offset.x
			var sub_rect := Rect2(source_region.position + Vector2(col * piece_size.x, row * piece_size.y), piece_size)

			var chunk := RigidBody2D.new()
			chunk.collision_layer = FRAGMENT_LAYER
			chunk.collision_mask = FRAGMENT_WORLD_LAYER
			chunk.gravity_scale = 3.2
			chunk.linear_damp = 2.0
			chunk.angular_damp = 1.5
			chunk.z_index = 3

			var sprite := Sprite2D.new()
			sprite.texture = source_tex
			sprite.region_enabled = true
			sprite.region_rect = sub_rect
			sprite.scale = piece_scale
			chunk.add_child(sprite)

			var shape := RectangleShape2D.new()
			shape.size = piece_size * piece_scale
			var collision := CollisionShape2D.new()
			collision.shape = shape
			chunk.add_child(collision)

			parent.add_child(chunk)
			chunk.global_position = enemy.global_position + (visual_offset + offset) * exit_scale
			chunk.rotation = randf_range(0.0, TAU)
			chunk.linear_velocity = Vector2.from_angle(blast_angle + randf_range(-FRAGMENT_SPREAD, FRAGMENT_SPREAD)) \
				* randf_range(FRAGMENT_SPEED_MIN, FRAGMENT_SPEED_MAX) + Vector2(0.0, -FRAGMENT_LIFT)
			chunk.angular_velocity = randf_range(-10.0, 10.0)

			var fade := chunk.create_tween()
			fade.tween_interval(FRAGMENT_LINGER)
			fade.tween_property(chunk, "modulate:a", 0.0, FRAGMENT_FADE)
			fade.tween_callback(chunk.queue_free)

## Which way the gibs should go: the way the blow was pointing, or away from the
## mole when the hit didn't say (mole attacks land from wherever the mole is).
static func _fragment_blast_direction(enemy: Node2D, hit_dir: Vector2) -> Vector2:
	if hit_dir != Vector2.ZERO:
		return hit_dir.normalized()
	var tree := enemy.get_tree()
	if tree == null:
		return Vector2.UP
	var mole := tree.get_first_node_in_group("mole") as Node2D
	if mole != null:
		var away := enemy.global_position - mole.global_position
		if away != Vector2.ZERO:
			return away.normalized()
	return Vector2.UP
