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
@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hurtbox.add_to_group("enemy_hurtbox")
	visual.play()

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
		_update_visual_direction()
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
	_update_visual_direction()

func _update_visual_direction() -> void:
	var dir = sign(velocity.x) if velocity.x != 0.0 else direction
	visual.scale.x = -abs(visual.scale.x) * sign(dir)

func _find_target() -> void:
	if target_mole == null or not is_instance_valid(target_mole):
		target_mole = get_tree().get_first_node_in_group("mole")
	elif global_position.distance_squared_to(target_mole.global_position) > DETECT_RANGE * DETECT_RANGE:
		target_mole = null

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		body.take_damage(1, global_position, true)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == hitbox or not area.monitoring:
		return
	var parent = area.get_parent()
	if parent.has_method("is_swinging"):
		if parent.is_swinging:
			die()
	else:
		die()

func die() -> void:
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.8, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		visual.visible = false

		var explosion := CPUParticles2D.new()
		explosion.emitting = true
		explosion.one_shot = true
		explosion.amount = 24
		explosion.lifetime = 0.5
		explosion.explosiveness = 1.0
		explosion.direction = Vector2.ZERO
		explosion.spread = 360.0
		explosion.initial_velocity_min = 150.0
		explosion.initial_velocity_max = 350.0
		explosion.gravity = Vector2(0, 200)
		explosion.damping_min = 50.0
		explosion.damping_max = 150.0
		explosion.scale_amount_min = 2.0
		explosion.scale_amount_max = 4.0
		explosion.color = Color(0.5, 0.25, 0.1, 1.0)
		var fade := Gradient.new()
		fade.set_color(0, Color(0.7, 0.35, 0.1, 1.0))
		fade.set_color(1, Color(0.3, 0.15, 0.05, 0.0))
		explosion.color_ramp = fade
		add_child(explosion)
		explosion.global_position = global_position
	)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)
