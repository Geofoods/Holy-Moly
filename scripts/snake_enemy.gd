extends CharacterBody2D

## A ground snake that slithers along the floor, rears up to telegraph, then strikes.

signal died

const PATROL_SPEED := 150.0
const STRIKE_SPEED := 900.0
const GRAVITY := 1960.0
const DETECT_RANGE_X := 360.0
const DETECT_RANGE_Y := 90.0
const REAR_DURATION := 0.5
const STRIKE_DURATION := 0.38
const COOLDOWN_DURATION := 0.8
const MAX_HEALTH := 14.0
const MOVE_SFX_INTERVAL := 0.5
const SPRAY_CHANCE := 0.35
const FORCE_SPRAY_DISTANCE := 230.0
const VENOM_COUNT := 3
const VENOM_SPREAD_DEGREES := 16.0

const EnemyDamage := preload("res://scripts/enemy.gd")
const VENOM_SCENE := preload("res://scenes/snake_venom.tscn")

enum State { PATROL, REAR, STRIKE, COOLDOWN }

var state := State.PATROL
var direction := 1.0
var state_timer := 0.0
var target_mole: Node2D = null
var health := MAX_HEALTH
var _stun_timer := 0.0
var _slither_time := 0.0
var _move_sfx_timer := 0.0
var _mole_in_contact := false
var _health_bar: Node2D = null

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var ray_right: RayCast2D = $RayRight
@onready var ray_left: RayCast2D = $RayLeft
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.z_index = 1
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	_find_target()
	_slither_time += delta

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if _stun_timer > 0.0:
		_stun_timer -= delta
		move_and_slide()
		return

	match state:
		State.PATROL:
			_do_patrol()
		State.REAR:
			_do_rear(delta)
		State.STRIKE:
			_do_strike(delta)
		State.COOLDOWN:
			_do_cooldown(delta)

	move_and_slide()
	_play_move_sound(delta)

func _do_patrol() -> void:
	velocity.x = direction * PATROL_SPEED
	_check_edges()
	visual.flip_h = direction < 0.0
	visual.rotation = sin(_slither_time * 16.0) * 0.12 * -direction
	if target_mole == null:
		return
	var offset := target_mole.global_position - global_position
	if absf(offset.x) < DETECT_RANGE_X and absf(offset.y) < DETECT_RANGE_Y and _has_line_of_sight(target_mole):
		_enter_rear(offset.x)

func _enter_rear(facing: float) -> void:
	state = State.REAR
	state_timer = REAR_DURATION
	direction = signf(facing) if facing != 0.0 else direction
	velocity.x = 0.0

func _do_rear(delta: float) -> void:
	velocity.x = 0.0
	visual.flip_h = direction < 0.0
	visual.rotation = lerp_angle(visual.rotation, -PI / 5.5 * direction, 0.3)
	visual.offset.x = sin(_slither_time * 55.0) * 3.0
	state_timer -= delta
	if state_timer <= 0.0:
		visual.offset.x = 0.0
		if _should_spray():
			_fire_venom()
			_enter_cooldown()
		else:
			_enter_strike()

func _enter_strike() -> void:
	state = State.STRIKE
	state_timer = STRIKE_DURATION
	visual.rotation = 0.0
	velocity.x = direction * STRIKE_SPEED
	SFX.play("enemy_fire", global_position, -8.0, 0.3)

func _do_strike(delta: float) -> void:
	velocity.x = direction * STRIKE_SPEED
	visual.flip_h = direction < 0.0
	state_timer -= delta
	if state_timer <= 0.0 or is_on_wall():
		_enter_cooldown()

func _enter_cooldown() -> void:
	state = State.COOLDOWN
	state_timer = COOLDOWN_DURATION
	velocity.x = 0.0

func _do_cooldown(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	visual.flip_h = direction < 0.0
	visual.rotation = lerp_angle(visual.rotation, 0.0, 0.2)
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.PATROL

func _check_edges() -> void:
	if is_on_wall():
		direction *= -1.0
	elif is_on_floor():
		if direction > 0.0 and not ray_right.is_colliding():
			direction *= -1.0
		elif direction < 0.0 and not ray_left.is_colliding():
			direction *= -1.0

func _has_line_of_sight(target: Node2D) -> bool:
	if absf(target.global_position.y - global_position.y) > 80.0:
		return false
	var ray_end := Vector2(target.global_position.x, global_position.y)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, ray_end, 1)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == target or result.collider == target.get_parent()

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)

func _play_move_sound(delta: float) -> void:
	if health <= 0 or velocity.x == 0.0:
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer <= 0.0:
		if state == State.STRIKE:
			_move_sfx_timer = 0.12
			SFX.play("dig_dash", global_position, -20.0, 0.3)
		else:
			_move_sfx_timer = MOVE_SFX_INTERVAL
			SFX.play("land", global_position, -22.0, 0.15)

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
		var mole = get_tree().get_first_node_in_group("mole")
		if mole:
			var dir = (global_position - mole.global_position).normalized()
			velocity = dir * 600.0 + Vector2(0, -250)
			_stun_timer = 0.25
		take_damage(parent.get_damage())

func take_damage(amount: float) -> void:
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
	var bar_w := 64.0
	var bar_h := 8.0
	var offset := Vector2(-bar_w / 2, -104)
	var ratio := health / MAX_HEALTH
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(0.3 + 0.7 * ratio, 0.8, 0.3, 0.95)
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	died.emit()
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	Shop.drop_coins(global_position, randi_range(1, 3))
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

func _break_apart() -> void:
	visual.visible = false

	var source_tex := visual.texture
	var source_region := Rect2(Vector2.ZERO, source_tex.get_size())

	var w := source_region.size.x
	var h := source_region.size.y
	var ox := source_region.position.x
	var oy := source_region.position.y

	var cols := 4
	var rows := 2
	var pw := w / cols
	var ph := h / rows
	var center_offset := Vector2(w * 0.5, h * 0.5)

	for col in cols:
		for row in rows:
			var local_center := Vector2(col * pw + pw * 0.5, row * ph + ph * 0.5) - center_offset
			var sub_rect := Rect2(ox + col * pw, oy + row * ph, pw, ph)

			var piece := Sprite2D.new()
			piece.texture = source_tex
			piece.region_enabled = true
			piece.region_rect = sub_rect
			piece.scale = visual.scale * 0.5
			piece.position = visual.position + local_center
			add_child(piece)

			var angle := randf_range(0.0, TAU)
			var speed := randf_range(150.0, 350.0)
			var vel := Vector2.RIGHT.rotated(angle) * speed

			var pt := create_tween()
			pt.tween_property(piece, "position", piece.position + vel, 0.5).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(piece, "rotation", randf_range(-4.0, 4.0), 0.5).set_ease(Tween.EASE_OUT)
			pt.parallel().tween_property(piece, "modulate", Color(1, 1, 1, 0), 0.5).set_ease(Tween.EASE_IN)
			pt.tween_callback(piece.queue_free)

func _should_spray() -> bool:
	if target_mole == null or not is_instance_valid(target_mole):
		return false
	var dist := global_position.distance_to(target_mole.global_position)
	var chance := SPRAY_CHANCE
	if dist >= FORCE_SPRAY_DISTANCE:
		chance = 1.0
	elif dist >= 130.0:
		chance = 0.6
	return randf() < chance

func _fire_venom() -> void:
	SFX.play("enemy_fire", global_position, -4.0, 0.2)
	var aim := Vector2(direction, 0.0)
	if target_mole and is_instance_valid(target_mole):
		aim = (target_mole.global_position - global_position).normalized()
	var base_angle := aim.angle()
	for i in VENOM_COUNT:
		var a := base_angle + deg_to_rad(VENOM_SPREAD_DEGREES) * (i - (VENOM_COUNT - 1) / 2.0)
		var proj = VENOM_SCENE.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position + aim * 16.0 + Vector2(0, -18)
		proj.direction = Vector2.from_angle(a)
		proj.source_snake = self