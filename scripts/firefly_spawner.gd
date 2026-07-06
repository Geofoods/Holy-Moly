extends Node2D

const MAX_FIREFLIES := 60
const SPAWN_RADIUS := 1800.0
const DESPAWN_DIST := 2200.0

var firefly_scene := preload("res://scenes/firefly.tscn")
var _poll_timer := 0.0
const POLL_INTERVAL := 0.4

func _ready() -> void:
	process_mode = PROCESS_MODE_WHEN_PAUSED

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer < POLL_INTERVAL:
		return
	_poll_timer = 0.0

	var mole := get_tree().get_first_node_in_group("mole")
	if not mole:
		return

	var count := 0
	var to_free: Array[Node] = []
	for child in get_children():
		if child is Node2D and not is_instance_valid(child):
			continue
		if child.global_position.distance_squared_to(mole.global_position) > DESPAWN_DIST * DESPAWN_DIST:
			to_free.append(child)
		else:
			count += 1
	for child in to_free:
		child.queue_free()

	while count < MAX_FIREFLIES:
		var f := firefly_scene.instantiate()
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(50.0, SPAWN_RADIUS)
		f.global_position = mole.global_position + Vector2(cos(angle), sin(angle)) * dist
		add_child(f)
		count += 1
