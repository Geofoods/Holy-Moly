extends CharacterBody2D

## Flying enemy that hovers near the player, then telegraphs and dashes at them periodically.
## The dash chews straight through terrain, and the stinger leaves the mole poisoned.

signal died

enum State { HOVER, AIM, DASH, RECOVER }

const HOVER_SPEED := 180.0
const DASH_SPEED := 720.0
const DASH_DURATION := 3.0
const AIM_DURATION := 0.6
const RECOVER_DURATION := 0.7
const RECOVER_LIFT_SPEED := 320.0
const DASH_COOLDOWN := 2.5
const HOVER_DISTANCE := 220.0
const DETECT_RANGE_X := 480.0
const DETECT_RANGE_Y := 900.0
const HOVER_HEIGHT_OFFSET := 150.0
const MAX_HEALTH := 20.0
const GRAVITY := 1400.0
const BUZZ_SFX_INTERVAL := 0.45
const HURT_DURATION := 0.5
const CONTACT_DAMAGE := 1.0
## Sting damage plus the venom slow, matching the Cave Snake globs.
const STING_DAMAGE := 1.0
const STING_SLOW_DURATION := 2.5
## Tiles a single charge is allowed to smash before it stalls on bedrock or a door.
const DASH_MAX_BREAKS := 6

const EnemyDamage := preload("res://scripts/enemy.gd")
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

var state := State.HOVER
var direction := 1.0
var dash_direction := Vector2.RIGHT
var dash_timer := 0.0
var cooldown_timer := 0.0
var health := MAX_HEALTH
var target_mole: Node2D = null
var detect_range_x := DETECT_RANGE_X
var detect_range_y := DETECT_RANGE_Y
## Backwards-compatible single-value override (e.g. queen_bee.gd); scales both
## axes of the detection rectangle, keeping its tall aspect ratio.
var detect_range: float:
	set(value):
		var scale_factor := value / DETECT_RANGE_Y
		detect_range_y = value
		detect_range_x = DETECT_RANGE_X * scale_factor
	get:
		return detect_range_y
var _buzz_timer := 0.0
var _mole_in_contact := false
var _health_bar: Node2D = null
var _hurt_timer := 0.0
var _dash_breaks := 0

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.play("idle")
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	_find_target()
	cooldown_timer -= delta

	match state:
		State.HOVER:
			_do_hover(delta)
		State.AIM:
			_do_aim(delta)
		State.DASH:
			_do_dash(delta)
		State.RECOVER:
			_do_recover(delta)

	_update_visual_direction()
	move_and_slide()
	_play_buzz(delta)

func _do_hover(delta: float) -> void:
	# Float toward the player, keeping some distance; drift on patrol when no target.
	if target_mole != null:
		var hover_target := target_mole.global_position - Vector2(0, HOVER_HEIGHT_OFFSET)
		var to_target := hover_target - global_position
		var desired := to_target.normalized() * HOVER_SPEED
		if absf(to_target.x) < HOVER_DISTANCE:
			desired.x = 0.0
		velocity.x = move_toward(velocity.x, desired.x, HOVER_SPEED * 2.0 * delta)
		velocity.y = move_toward(velocity.y, desired.y, HOVER_SPEED * 2.0 * delta)
		if absf(to_target.x) > 40.0:
			direction = signf(to_target.x)
	else:
		velocity.x = move_toward(velocity.x, direction * HOVER_SPEED * 0.5, HOVER_SPEED * delta)
		velocity.y = sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 40.0

	if is_on_wall():
		direction *= -1.0

	if target_mole != null and cooldown_timer <= 0.0 and _within_detect_rect(target_mole.global_position):
		_enter_aim()

func _within_detect_rect(pos: Vector2) -> bool:
	var offset := pos - global_position
	return absf(offset.x) < detect_range_x and absf(offset.y) < detect_range_y

func _enter_aim() -> void:
	state = State.AIM
	dash_timer = AIM_DURATION
	velocity = Vector2.ZERO
	visual.play("spinstart")

func _do_aim(delta: float) -> void:
	# Shake while locking on, orienting its stinger toward the target until the last moment.
	if target_mole != null:
		dash_direction = (target_mole.global_position - global_position).normalized()
		velocity = dash_direction * 40.0
	visual.rotation = dash_direction.angle() - PI / 2.0
	dash_timer -= delta
	visual.offset.x = sin(dash_timer * 80.0) * 4.0
	if dash_timer <= 0.0:
		visual.offset.x = 0.0
		_enter_dash()

func _enter_dash() -> void:
	state = State.DASH
	dash_timer = DASH_DURATION
	_dash_breaks = 0
	velocity = dash_direction * DASH_SPEED
	visual.rotation = dash_direction.angle() - PI / 2.0
	visual.play("spinning")
	SFX.play("swing", global_position, -8.0, 0.4)

func _do_dash(delta: float) -> void:
	dash_timer -= delta
	var broke_through := _dash_break_tiles()
	# Smash the terrain it slams into and keep charging, so a dash tunnels
	# through cave walls instead of being stopped by the first block.
	if not broke_through and (is_on_wall() or is_on_floor() or is_on_ceiling()):
		dash_timer = 0.0
	if dash_timer <= 0.0:
		_enter_recover()

## Erases dash collision blockers and nearby decoration. Returns true when a
## solid tile was cleared, so dash impact logic does not stop on that frame.
func _dash_break_tiles() -> bool:
	if _dash_breaks >= DASH_MAX_BREAKS:
		return false
	var world := get_parent()
	var broke_solid := false
	for i in get_slide_collision_count():
		if _dash_breaks >= DASH_MAX_BREAKS:
			break
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if not (collider is TileMap):
			continue
		var tilemap := collider as TileMap
		# Step just inside the contact point so the probe lands in the block
		# rather than the empty cell the dash is about to travel into.
		var probe := collision.get_position() + collision.get_normal() * -8.0
		var tile_pos := tilemap.local_to_map(tilemap.to_local(probe))
		var source_id := tilemap.get_cell_source_id(0, tile_pos)
		if source_id == -1:
			TileBreakSFX.break_decoration_tile(tilemap, tile_pos, world)
			continue
		var tile_data := tilemap.get_cell_tile_data(0, tile_pos)
		if tile_data and tile_data.get_custom_data("bedrock"):
			continue
		TileBreakSFX.break_tile(tilemap, tile_pos, world)
		_dash_breaks += 1
		broke_solid = true
	return broke_solid

func _enter_recover() -> void:
	state = State.RECOVER
	dash_timer = RECOVER_DURATION
	velocity *= 0.2
	visual.offset.x = 0.0
	visual.rotation = 0.0
	_hurt_timer = HURT_DURATION
	visual.play("hurt")

func _do_recover(delta: float) -> void:
	# Dazed for a beat, then tired drift upward until the cooldown lets it hover/dash again.
	dash_timer -= delta
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			visual.play("idle")
	velocity.x = move_toward(velocity.x, 0.0, HOVER_SPEED * delta)
	# Always climb back to altitude after an attack, even if it's still touching the floor.
	velocity.y = move_toward(velocity.y, -RECOVER_LIFT_SPEED, GRAVITY * 0.6 * delta)
	if dash_timer <= 0.0:
		state = State.HOVER
		cooldown_timer = DASH_COOLDOWN

func _update_visual_direction() -> void:
	if state != State.HOVER:
		return
	if absf(velocity.x) > 1.0:
		# Idle art faces left by default, so flip it to face right.
		visual.flip_h = velocity.x > 0.0

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)
	elif not _within_detect_rect(target_mole.global_position):
		target_mole = null

func _on_hitbox_body_entered(body: Node) -> void:
	if not body.is_in_group("mole") or _mole_in_contact:
		return
	_mole_in_contact = true
	if state == State.DASH:
		_sting(body)
		# Stop dashing the moment it connects with the player.
		_enter_recover()
	else:
		body.take_damage(CONTACT_DAMAGE, global_position, true)

## The dash is the sting: contact damage plus a venom slow, with a green puff so
## the poison reads on screen the way the Cave Snake globs do.
func _sting(body: Node) -> void:
	body.take_damage(STING_DAMAGE, global_position, true)
	if body.has_method("apply_slow"):
		body.apply_slow(STING_SLOW_DURATION)
	_spawn_venom_puff(global_position.lerp(body.global_position, 0.5))
	SFX.play("hurt", global_position, -6.0, 0.1, 0.9)

func _spawn_venom_puff(world_pos: Vector2) -> void:
	var puff := CPUParticles2D.new()
	puff.emitting = true
	puff.one_shot = true
	puff.amount = 10
	puff.lifetime = 0.4
	puff.explosiveness = 1.0
	puff.direction = Vector2.ZERO
	puff.spread = 180.0
	puff.initial_velocity_min = 40.0
	puff.initial_velocity_max = 120.0
	puff.gravity = Vector2(0, 220)
	puff.scale_amount_min = 4.0
	puff.scale_amount_max = 8.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 1.0, 0.3, 0.8))
	grad.set_color(1, Color(0.3, 0.8, 0.15, 0.0))
	puff.color_ramp = grad
	get_parent().add_child(puff)
	puff.global_position = world_pos
	get_tree().create_timer(puff.lifetime + 0.3).timeout.connect(puff.queue_free)

func _on_hitbox_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_in_contact = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == hitbox or not area.monitoring:
		return
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		# Knock the hornet out of the air mid-behavior when shovelled.
		if state == State.DASH or state == State.AIM:
			_enter_recover()
			cooldown_timer = DASH_COOLDOWN
		velocity = (global_position - parent.global_position).normalized() * 500.0 + Vector2(0, -200)
		take_damage(parent.get_damage())

## Takes the hit direction the fragment-spawning enemies use for their death
## gibs; this one just shrinks away, so it ignores it.
func take_damage(amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0:
		return
	health -= amount
	EnemyDamage.spawn_damage_number(self, amount)
	SFX.play("enemy_hit", global_position)
	if _health_bar:
		_health_bar.queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2, 1, 1, 1), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	if health <= 0:
		die()

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
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)

func _play_buzz(delta: float) -> void:
	if health <= 0:
		return
	_buzz_timer -= delta
	if _buzz_timer <= 0.0:
		_buzz_timer = BUZZ_SFX_INTERVAL
		SFX.play("swing", global_position, -24.0, 0.5 if state == State.DASH else 0.15)
