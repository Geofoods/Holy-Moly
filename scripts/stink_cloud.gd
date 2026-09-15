extends Area2D

## A lingering cloud of stink. Applies a slow to any enemy inside it every tick
## (enemies are tracked via the enemy_hurtbox group).

const RADIUS := 150.0
const DURATION := 6.0
const SLOW_FACTOR := 0.35

var _time := 0.0
var _slow_tick := 0.0

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	monitoring = true
	monitorable = false
	z_index = -1

func _process(delta: float) -> void:
	_time += delta
	_slow_tick -= delta
	queue_redraw()
	if _time >= DURATION:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(queue_free)
		set_process(false)
		return
	if _slow_tick <= 0.0:
		_slow_tick = 0.4
		for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
			if not is_instance_valid(hurtbox):
				continue
			var enemy := hurtbox.get_parent()
			if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= RADIUS + 30.0:
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.45, SLOW_FACTOR)

func _draw() -> void:
	var pulse := 0.28 + sin(_time * 5.0) * 0.06
	draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.9, 0.42, pulse))
	draw_circle(Vector2.ZERO, RADIUS * 0.55, Color(0.65, 0.95, 0.5, pulse * 0.8))