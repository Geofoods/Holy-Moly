extends Node2D

const SPEED := 30.0
const WANDER_RADIUS := 250.0
## Fireflies are tiny decorations: once the mole is more than this far away
## (e.g. digging deep or far away), stop simulating them every frame. They
## resume when the mole comes back.
const SIM_PAUSE_DIST := 1400.0
## Seconds between mole distance checks (cheap: one distance_squared call).
const MOLE_CHECK_INTERVAL := 0.5

var origin: Vector2
var wander_target: Vector2
var float_phase := 0.0

@export var color := Color(1, 0.9, 0.4, 0.9):
	set(value):
		color = value
		if is_instance_valid(body):
			body.color = color

var _mole: Node2D = null
var _mole_check_timer := 0.0
var _last_glow := -1.0

@onready var body: ColorRect = $Body

func _ready() -> void:
	body.color = color
	origin = global_position
	wander_target = origin
	float_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	_mole_check_timer -= delta
	if _mole_check_timer <= 0.0:
		_mole_check_timer = MOLE_CHECK_INTERVAL
		_mole = get_tree().get_first_node_in_group("mole")
	if _mole != null and not is_instance_valid(_mole):
		_mole = null
	if _mole != null:
		# Squared distance against a generous threshold; far fireflies idle.
		if global_position.distance_squared_to(_mole.global_position) > SIM_PAUSE_DIST * SIM_PAUSE_DIST:
			return

	float_phase += delta * 4.0
	position += Vector2(0.0, sin(float_phase) * delta * 16.0)

	if global_position.distance_squared_to(wander_target) < 200.0:
		wander_target = origin + Vector2(randf_range(-WANDER_RADIUS, WANDER_RADIUS), randf_range(-WANDER_RADIUS, WANDER_RADIUS))

	var dir := (wander_target - global_position).normalized()
	position += dir * SPEED * delta

	var glow := 0.8 + sin(float_phase * 0.7) * 0.4
	if not is_equal_approx(glow, _last_glow):
		_last_glow = glow
		body.color.a = glow
