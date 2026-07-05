extends Node2D

const MAX_FIREFLIES := 80
const SPAWN_RADIUS := 1800.0
const DESPAWN_DIST := 2200.0

var firefly_scene := preload("res://scenes/firefly.tscn")

func _process(_delta: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	if not mole:
		return

	var count := 0
	for child in get_children():
		if child is Node2D and not is_instance_valid(child):
			continue
		if child.global_position.distance_squared_to(mole.global_position) > DESPAWN_DIST * DESPAWN_DIST:
			child.queue_free()
		else:
			count += 1

	while count < MAX_FIREFLIES:
		var f := firefly_scene.instantiate()
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(50.0, SPAWN_RADIUS)
		f.global_position = mole.global_position + Vector2(cos(angle), sin(angle)) * dist
		add_child(f)
		count += 1
