extends AnimatableBody2D

## A moving platform that ping-pongs back and forth along a line, carrying
## anything standing on it. Tune the exported properties per instance.

@export var motion_direction := Vector2.RIGHT
@export var travel_distance := 320.0
@export var speed := 140.0
@export var platform_size := Vector2(260.0, 36.0)

var _origin := Vector2.ZERO
var _elapsed := 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_origin = global_position
	var shape := RectangleShape2D.new()
	shape.size = platform_size
	_collision.shape = shape
	_collision.position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var dir := motion_direction.normalized()
	var phase := fposmod(_elapsed * speed, travel_distance * 2.0)
	var offset := travel_distance - absf(phase - travel_distance)
	global_position = _origin + dir * offset

func _draw() -> void:
	var half := platform_size / 2.0
	draw_rect(Rect2(-half, -half), Color(0.45, 0.32, 0.18))
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(platform_size.x, 6.0)), Color(0.65, 0.48, 0.27))
	draw_rect(Rect2(Vector2(-half.x, half.y - 6.0), Vector2(platform_size.x, 6.0)), Color(0.3, 0.21, 0.11))
