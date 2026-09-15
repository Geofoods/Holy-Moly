extends CharacterBody2D

## A heavy boulder the mole can push. Slides along the ground, settles on
## floors, and drops over ledges. The mole shoves it by walking into it.

const ROCK_RADIUS := 36.0
const GRAVITY := 2450.0
const MAX_FALL_SPEED := 1200.0
const PUSH_SPEED := 700.0
const ACCELERATION := 3600.0
const FRICTION := 3600.0

var _push_velocity := Vector2.ZERO

func _ready() -> void:
	add_to_group("pushable")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0

	var push_dir := _push_velocity
	_push_velocity = Vector2.ZERO
	var target_x := push_dir.x * PUSH_SPEED
	if target_x != 0.0:
		velocity.x = move_toward(velocity.x, target_x, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()

func push(direction: Vector2) -> void:
	_push_velocity = direction

func _draw() -> void:
	var center := Vector2.ZERO
	draw_circle(center + Vector2(0, ROCK_RADIUS + 10), ROCK_RADIUS * 0.55, Color(0, 0, 0, 0.25))
	draw_circle(center + Vector2(3, 4), ROCK_RADIUS, Color(0.13, 0.12, 0.14))
	draw_circle(center, ROCK_RADIUS, Color(0.42, 0.40, 0.43))
	draw_circle(center + Vector2(-15, -17), ROCK_RADIUS * 0.62, Color(0.58, 0.55, 0.58))
	draw_arc(center + Vector2(0, -6), ROCK_RADIUS - 8.0, PI, PI * 2.0, 26, Color(0.70, 0.68, 0.72), 6.0)
	draw_line(center + Vector2(-22, 6), center + Vector2(0, 22), Color(0.24, 0.22, 0.25), 3.0)
	draw_line(center + Vector2(0, 22), center + Vector2(18, 13), Color(0.24, 0.22, 0.25), 3.0)
	draw_line(center + Vector2(12, -8), center + Vector2(28, -22), Color(0.24, 0.22, 0.25), 3.0)