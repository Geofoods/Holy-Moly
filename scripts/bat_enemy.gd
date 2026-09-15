extends CharacterBody2D

const SPEED = 300.0
const SINE_AMPLITUDE = 80.0
const SINE_FREQUENCY = 5.0
const SWOOP_SPEED = 500.0
const DETECT_RANGE = 300.0
const MAX_HEALTH := 12.0
const MOVE_SFX_INTERVAL := 0.35

const EnemyDamage := preload("res://scripts/enemy.gd")

var direction := 1.0
var sine_time := 0.0
var base_y := 0.0
var swooping := false
var target_mole: Node2D = null
var health := MAX_HEALTH
var _stun_timer := 0.0
var _move_sfx_timer := 0.0
var _mole_in_contact := false
var _health_bar: Node2D = null

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	base_y = global_position.y
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)
	hurtbox.add_to_group("enemy_hurtbox")
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)

	if _stun_timer > 0.0:
		_stun_timer -= delta
		move_and_slide()
		return

	var dist := INF
	if target_mole != null:
		dist = global_position.distance_to(target_mole.global_position)

	swooping = target_mole != null and dist < DETECT_RANGE and _has_line_of_sight(target_mole)

	if swooping and target_mole != null:
		var swoop_dir := (target_mole.global_position - global_position).normalized()
		velocity = swoop_dir * SWOOP_SPEED
		base_y = global_position.y
		sine_time = 0.0
	else:
		sine_time += delta
		velocity.x = direction * SPEED
		var target_y := base_y + sin(sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE
		velocity.y = (target_y - global_position.y) / maxf(delta, 0.001)

	if is_on_wall():
		direction *= -1.0

	visual.flip_h = velocity.x < 0 if velocity.x != 0 else direction < 0

	move_and_slide()
	_play_move_sound(delta)

func _play_move_sound(delta: float) -> void:
	if health <= 0:
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer <= 0.0:
		if swooping:
			_move_sfx_timer = 0.2
			SFX.play("swing", global_position, -16.0, 0.3)
		else:
			_move_sfx_timer = MOVE_SFX_INTERVAL
			SFX.play("swing", global_position, -22.0, 0.2)

func _has_line_of_sight(target: Node2D) -> bool:
	if target == null:
		return false
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == target or result.collider == target.get_parent()

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
	if health <= 0:
		return
	if not is_instance_valid(_health_bar):
		return
	var bar_w := 56.0
	var bar_h := 8.0
	var offset := Vector2(-bar_w / 2, -70)
	var ratio := health / MAX_HEALTH
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(0.3 + 0.7 * ratio, 0.8, 0.3, 0.95)
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	Shop.drop_coins(global_position, randi_range(2, 4))
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)