extends CharacterBody2D

const PATROL_SPEED = 160.0
const CHARGE_SPEED = 800.0
const GRAVITY = 1960.0
const DETECT_RANGE_X = 350.0
const DETECT_RANGE_Y = 60.0
const CHARGE_DURATION = 0.4
const CHARGE_COOLDOWN = 0.75

enum State { PATROL, CHARGING, COOLDOWN }

var state := State.PATROL
var direction := 1.0
var state_timer := 0.0
var target_mole: Node2D = null
var _move_sfx_timer := 0.0
const MOVE_SFX_INTERVAL := 0.45

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var ray_right: RayCast2D = $RayRight
@onready var ray_left: RayCast2D = $RayLeft
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
		if target_mole:
			add_collision_exception_with(target_mole)

	match state:
		State.PATROL:
			velocity.x = direction * PATROL_SPEED
			_check_edges()
			visual.flip_h = direction < 0
			if target_mole:
				var offset := target_mole.global_position - global_position
				if abs(offset.x) < DETECT_RANGE_X and abs(offset.y) < DETECT_RANGE_Y and _has_line_of_sight(target_mole):
					state = State.CHARGING
					state_timer = CHARGE_DURATION
					direction = sign(offset.x) if offset.x != 0.0 else direction

		State.CHARGING:
			velocity.x = direction * CHARGE_SPEED
			visual.flip_h = direction < 0
			state_timer -= delta
			if state_timer <= 0.0 or is_on_wall():
				state = State.COOLDOWN
				state_timer = CHARGE_COOLDOWN
				velocity.x = 0

		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0, 600.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.PATROL

	move_and_slide()
	_play_move_sound(delta)

func _play_move_sound(delta: float) -> void:
	if velocity.x == 0.0:
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer <= 0.0:
		if state == State.CHARGING:
			_move_sfx_timer = 0.12
			SFX.play("dig_dash", global_position, -20.0, 0.3)
		else:
			_move_sfx_timer = MOVE_SFX_INTERVAL
			SFX.play("dig_dash", global_position, -22.0, 0.15)

func _has_line_of_sight(target: Node2D) -> bool:
	if abs(target.global_position.y - global_position.y) > 80.0:
		return false
	var ray_end := Vector2(target.global_position.x, global_position.y)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, ray_end, 1)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == target or result.collider == target.get_parent()

func _check_edges() -> void:
	if is_on_wall():
		direction *= -1.0
	elif is_on_floor():
		if direction > 0 and not ray_right.is_colliding():
			direction *= -1.0
		elif direction < 0 and not ray_left.is_colliding():
			direction *= -1.0

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	die()

func die() -> void:
	SFX.play("enemy_death", global_position)
	ComboManager.increment()
	Shop.drop_coins(global_position, randi_range(1, 3))
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.05)
	tween.tween_property(visual, "modulate", Color(0.3, 0.7, 0.1), 0.05)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
