extends Node2D

## Vacuum Jelly: a squishy blob that yanks every coin within RANGE straight to
## the mole for DURATION seconds. Coins are pulled hard, then collected by their
## own magnet once close enough.

const RANGE := 950.0
const DURATION := 1.4
const PULL_SPEED := 2600.0

var _time := 0.0

func _ready() -> void:
	z_index = 1

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole:
		for coin in get_tree().get_nodes_in_group("coin"):
			if not is_instance_valid(coin):
				continue
			var c := coin as RigidBody2D
			var dist := c.global_position.distance_to(mole.global_position)
			if dist > RANGE:
				continue
			c.sleeping = false
			c.linear_velocity = (mole.global_position - c.global_position).normalized() * PULL_SPEED
	if _time >= DURATION:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_callback(queue_free)
		set_process(false)

func _draw() -> void:
	var r := clampf(RANGE * 0.18, 40.0, 160.0)
	draw_circle(Vector2.ZERO, r, Color(0.55, 0.7, 1.0, 0.18 - _time * 0.04))
	draw_circle(Vector2.ZERO, r * 0.55, Color(0.7, 0.85, 1.0, 0.25))
	draw_circle(Vector2(-r * 0.15, -r * 0.2), r * 0.22, Color(0.85, 0.92, 1.0, 0.35))