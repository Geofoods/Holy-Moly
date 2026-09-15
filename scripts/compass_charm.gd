extends Node2D

## Compass Charm: conjures a ghost-mole arrow floating over the player that
## points toward the level exit for LIFETIME seconds.

const LIFETIME := 8.0

var _time := 0.0
var _mole: Node2D = null

func _ready() -> void:
	z_index = 60
	_mole = get_tree().get_first_node_in_group("mole")

func _process(delta: float) -> void:
	_time += delta
	if _mole and is_instance_valid(_mole):
		global_position = _mole.global_position + Vector2(0, -90)
	var exit := _find_exit()
	if exit == null or _time >= LIFETIME:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		set_process(false)
		return
	var dir := (exit.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	rotation = dir.angle()
	queue_redraw()

func _find_exit() -> Node2D:
	return get_tree().get_first_node_in_group("level_exit")

func _draw() -> void:
	var wobb := sin(_time * 8.0) * 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(26, 0), Vector2(-20, -16), Vector2(-8, 0), Vector2(-20, 16)]), Color(1.0, 0.9, 0.4, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(11, wobb * 0.4), Vector2(-30, wobb * 0.4), Vector2(-30, -14 + wobb * 0.4), Vector2(11, -14 + wobb * 0.4)]), Color(1.0, 0.95, 0.7, 0.35))