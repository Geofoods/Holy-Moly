extends CharacterBody2D

signal died

const GRAVITY := 1960.0
const THROW_INTERVAL := 2.5
const THROW_VELOCITY := 1600.0
const MAX_HEALTH := 40.0

const EnemyDamage := preload("res://scripts/enemy.gd")
# How far into the throw animation the mushroom is actually released, so the
# projectile leaves the goblin's hand as the throwing motion plays out.
const THROW_RELEASE_DELAY := 0.28

var health := MAX_HEALTH
var throw_cooldown := THROW_INTERVAL
var throw_anim_timer := 0.0
var target_mole: Node2D = null
var is_throwing := false
var _release_timer := 0.0
var _pending_release := false
var _idle_sfx_timer := 2.0
const IDLE_SFX_INTERVAL := 3.0
var _stun_timer := 0.0

var mushroom_scene := preload("res://explodingmushroom.tscn")

@onready var hurtbox: Area2D = $Area2D
@onready var visual: AnimatedSprite2D = $Visual
var _base_scale_x: float
var _health_bar: Node2D = null

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.z_index = 1
	# "default" is a non-looping idle→windup→throw animation. Rest on the idle
	# frame; the throw is played on demand in _throw_mushroom().
	visual.stop()
	visual.animation = "default"
	visual.frame = 0
	_base_scale_x = abs(visual.scale.x)
	_setup_health_bar()

func _physics_process(delta: float) -> void:
	_find_target()

	if _stun_timer > 0.0:
		_stun_timer -= delta
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		_update_facing()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if is_throwing:
		velocity.x = 0.0
		if _pending_release:
			_release_timer -= delta
			if _release_timer <= 0.0:
				_pending_release = false
				_release_mushroom()
		throw_anim_timer -= delta
		if throw_anim_timer <= 0.0:
			is_throwing = false
			_pending_release = false
			# Snap back to the idle frame and stop, so the goblin doesn't freeze
			# on the throw-release frame.
			visual.stop()
			visual.frame = 0
			throw_cooldown = THROW_INTERVAL
		move_and_slide()
		return

	velocity.x = 0.0
	move_and_slide()
	_update_facing()
	_play_idle_sound(delta)

	throw_cooldown -= delta
	if throw_cooldown <= 0.0 and target_mole and _is_on_screen() and _has_line_of_sight(target_mole):
		_throw_mushroom()

func _play_idle_sound(delta: float) -> void:
	if health <= 0:
		return
	_idle_sfx_timer -= delta
	if _idle_sfx_timer <= 0.0:
		_idle_sfx_timer = IDLE_SFX_INTERVAL + randf_range(-0.5, 0.5)
		SFX.play("land", global_position, -20.0, 0.6)

func _is_on_screen() -> bool:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return true
	var viewport_size := get_viewport().get_visible_rect().size
	var visible_world := viewport_size / camera.zoom
	var screen_rect := Rect2(camera.global_position - visible_world * 0.5, visible_world)
	return screen_rect.has_point(global_position)

func _has_line_of_sight(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if result.position.distance_to(target.global_position) < 40.0:
		return true
	return false

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)

func _update_facing() -> void:
	if not target_mole or not is_instance_valid(target_mole):
		return
	var diff := target_mole.global_position.x - global_position.x
	if abs(diff) < 30.0:
		return
	visual.scale.x = -_base_scale_x if diff >= 0 else _base_scale_x

func _throw_mushroom() -> void:
	SFX.play("enemy_fire", global_position)
	is_throwing = true
	throw_anim_timer = 0.6
	visual.frame = 0
	visual.play("default")

	if not target_mole or not is_instance_valid(target_mole):
		is_throwing = false
		visual.stop()
		visual.frame = 0
		throw_cooldown = THROW_INTERVAL
		return

	# Start the windup now; the mushroom is actually released a moment later so
	# it leaves the goblin's hand while the throwing motion is playing.
	_pending_release = true
	_release_timer = THROW_RELEASE_DELAY

func _release_mushroom() -> void:
	if not target_mole or not is_instance_valid(target_mole):
		return

	var dir := (target_mole.global_position - global_position).normalized()

	var mushroom = mushroom_scene.instantiate()
	get_parent().call_deferred("add_child", mushroom)
	mushroom.global_position = global_position + Vector2(sign(dir.x) * 30, -40)
	mushroom.linear_velocity = dir * THROW_VELOCITY
	mushroom.arm()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if "is_swinging" in parent and parent.is_swinging:
		var mole = get_tree().get_first_node_in_group("mole")
		if mole:
			var dir = (global_position - mole.global_position).normalized()
			velocity = dir * 600.0 + Vector2(0, -250)
			_stun_timer = 0.25
		take_damage(parent.get_damage())

## Direction the last hit pushed this enemy, so its death fragments are blown
## the same way (see spawn_death_fragments in enemy.gd).
var hit_direction := Vector2.ZERO

func take_damage(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0:
		return
	health -= amount
	if direction != Vector2.ZERO:
		hit_direction = direction.normalized()
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
	var bar_h := 10.0
	var offset := Vector2(-bar_w / 2, -110)
	var ratio := health / MAX_HEALTH

	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.15, 0.9))
	var fill := Color(1.0 * (1.0 - ratio) + 0.2 * ratio, 0.2 * (1.0 - ratio) + 0.8 * ratio, 0.2, 0.95)
	_health_bar.draw_rect(Rect2(offset, Vector2(bar_w * ratio, bar_h)), fill)

func die() -> void:
	died.emit()
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	Shop.drop_coins(global_position, randi_range(4, 6))
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_break_apart)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)

func _break_apart() -> void:
	EnemyDamage.spawn_death_fragments(self, visual, hit_direction, scale.x)
