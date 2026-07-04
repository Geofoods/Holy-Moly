extends CharacterBody2D

const SPEED = 80.0
const CLIMB_SPEED = 70.0
const GRAVITY = 980.0
const DETECT_RANGE = 600.0
const CLIMB_DURATION = 1.2
const CLIMB_CHANCE = 0.5

var direction := 1.0
var target_mole: Node2D = null
var is_climbing := false
var climb_timer := 0.0
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var visual: CanvasItem = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")

func _physics_process(delta: float) -> void:
	_find_target()

	if target_mole:
		direction = sign(target_mole.global_position.x - global_position.x)

	if is_climbing:
		climb_timer -= delta
		velocity.y = -CLIMB_SPEED
		velocity.x = direction * SPEED * 0.3
		if climb_timer <= 0.0 or is_on_ceiling():
			is_climbing = false
		move_and_slide()
		visual.scale.x = abs(visual.scale.x) * sign(facing())
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * SPEED

	if is_on_wall():
		if randf() < CLIMB_CHANCE and target_mole and target_mole.global_position.y < global_position.y - 30:
			is_climbing = true
			climb_timer = CLIMB_DURATION
		else:
			direction *= -1

	move_and_slide()
	visual.scale.x = abs(visual.scale.x) * sign(facing())

func facing() -> float:
	return sign(velocity.x) if velocity.x != 0.0 else direction

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
	elif global_position.distance_squared_to(target_mole.global_position) > DETECT_RANGE * DETECT_RANGE:
		target_mole = null

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == hitbox:
		return
	die()

func die() -> void:
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.05)
	tween.tween_property(visual, "modulate", Color(0.7, 0.2, 1.0), 0.05)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
