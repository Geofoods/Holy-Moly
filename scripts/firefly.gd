extends Node2D

const SPEED := 30.0
const WANDER_RADIUS := 100.0

var origin: Vector2
var wander_target: Vector2
var float_phase := 0.0

@onready var light: PointLight2D = $Light
@onready var body: ColorRect = $Body

func _ready() -> void:
	origin = global_position
	wander_target = origin
	float_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	float_phase += delta * 4.0
	position += Vector2(0.0, sin(float_phase) * delta * 16.0)

	if global_position.distance_squared_to(wander_target) < 200.0:
		wander_target = origin + Vector2(randf_range(-WANDER_RADIUS, WANDER_RADIUS), randf_range(-WANDER_RADIUS, WANDER_RADIUS))

	var dir := (wander_target - global_position).normalized()
	position += dir * SPEED * delta

	var glow := 0.8 + sin(float_phase * 0.7) * 0.4
	body.color.a = glow
	light.energy = glow * 2.0
