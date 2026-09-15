extends CharacterBody2D

## Flying enemy that hovers near the player, then telegraphs and dashes at them periodically.

signal died

enum State { HOVER, AIM, DASH, RECOVER }

const HOVER_SPEED := 180.0
const DASH_SPEED := 900.0
const DASH_DURATION := 0.45
const AIM_DURATION := 0.6
const RECOVER_DURATION := 0.7
const RECOVER_LIFT_SPEED := 320.0
const DASH_COOLDOWN := 2.5
const HOVER_DISTANCE := 220.0
const DETECT_RANGE := 520.0
const MAX_HEALTH := 20.0
const GRAVITY := 1400.0
const BUZZ_SFX_INTERVAL := 0.45

const EnemyDamage := preload("res://scripts/enemy.gd")

var state := State.HOVER
var direction := 1.0
var dash_direction := Vector2.RIGHT
var dash_timer := 0.0
var cooldown_timer := 0.0
var health := MAX_HEALTH
var target_mole: Node2D = null
var detect_range := DETECT_RANGE
var _buzz_timer := 0.0
var _mole_in_contact := false
var _health_bar: Node2D = null

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
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
		var to_target := target_mole.global_position - global_position
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

	if target_mole != null and cooldown_timer <= 0.0 and global_position.distance_to(target_mole.global_position) < detect_range:
		_enter_aim()

func _enter_aim() -> void:
	state = State.AIM
	dash_timer = AIM_DURATION
	velocity = Vector2.ZERO

func _do_aim(delta: float) -> void:
	# Shake while locking on, keep tracking the target until the last moment.
	if target_mole != null:
		dash_direction = (target_mole.global_position - global_position).normalized()
		velocity = dash_direction * 40.0
	dash_timer -= delta
	visual.offset.x = sin(dash_timer * 80.0) * 4.0
	if dash_timer <= 0.0:
		visual.offset.x = 0.0
		_enter_dash()

func _enter_dash() -> void:
	state = State.DASH
	dash_timer = DASH_DURATION
	velocity = dash_direction * DASH_SPEED
	SFX.play("swing", global_position, -8.0, 0.4)

func _do_dash(delta: float) -> void:
	dash_timer -= delta
	if is_on_wall() or is_on_floor() or is_on_ceiling():
		dash_timer = 0.0
	if dash_timer <= 0.0:
		_enter_recover()

func _enter_recover() -> void:
	state = State.RECOVER
	dash_timer = RECOVER_DURATION
	velocity *= 0.2
	visual.offset.x = 0.0

func _do_recover(delta: float) -> void:
	# Tired drift downward until the cooldown lets it hover/dash again.
	dash_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, HOVER_SPEED * delta)
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, 120.0, GRAVITY * 0.3 * delta)
	else:
		velocity.y = 0.0
	if dash_timer <= 0.0:
		state = State.HOVER
		cooldown_timer = DASH_COOLDOWN
		if is_on_floor():
			velocity.y = -RECOVER_LIFT_SPEED

func _update_visual_direction() -> void:
	if state == State.AIM and target_mole != null:
		visual.flip_h = dash_direction.x < 0.0
	elif absf(velocity.x) > 1.0:
		visual.flip_h = velocity.x < 0.0

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)
	elif global_position.distance_squared_to(target_mole.global_position) > detect_range * detect_range:
		target_mole = null

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
		# Knock the hornet out of the air mid-behavior when shovelled.
		if state == State.DASH or state == State.AIM:
			_enter_recover()
			cooldown_timer = DASH_COOLDOWN
		velocity = (global_position - parent.global_position).normalized() * 500.0 + Vector2(0, -200)
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
