extends CharacterBody2D
const SPEED = 120.0
const GRAVITY = 980.0

var direction := 1.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var ray_right: RayCast2D = $RayRight
@onready var ray_left: RayCast2D = $RayLeft
@onready var visual: ColorRect = $Visual

func _ready() -> void:
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	velocity.x = direction * SPEED

	# Reverse at walls or edges
	if is_on_wall():
		direction *= -1.0
	elif is_on_floor():
		if direction > 0 and ray_right.is_colliding() == false:
			direction *= -1.0
		elif direction < 0 and ray_left.is_colliding() == false:
			direction *= -1.0

	visual.scale.x = abs(visual.scale.x) * sign(direction)

	move_and_slide()

func _on_hurtbox_area_entered(_area: Area2D) -> void:
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
