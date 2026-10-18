extends Node

class_name ArenaProbe

## TEMPORARY probe: what actually collides where in the PvP arena.

const POINTS := [
	Vector2(150.0, 685.0),
	Vector2(1250.0, 685.0),
	Vector2(700.0, 325.0),
	Vector2(700.0, 65.0),
	Vector2(700.0, 700.0),
	Vector2(700.0, 790.0),
	Vector2(700.0, 900.0),
	Vector2(700.0, 0.0),
	Vector2(700.0, -300.0),
]

func _ready() -> void:
	await get_tree().process_frame
	# Verify the inherited PvP player scene actually instantiates.
	var pvp_packed: PackedScene = load("res://scenes/pvp_player.tscn") as PackedScene
	if pvp_packed == null:
		print("PROBE bad: cannot load pvp_player.tscn")
		get_tree().quit()
		return
	var pvp_player := pvp_packed.instantiate()
	add_child(pvp_player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("PROBE pvp_player class=%s script=%s" % [str(pvp_player.get_class()), str(pvp_player.get_script().resource_path if pvp_player.get_script() else "<none>")])
	if pvp_player.has_method("configure"):
		print("PROBE pvp_player has configure")
	else:
		print("PROBE pvp_player MISSING configure")
	pvp_player.queue_free()
	# Verify the arena scene still loads.
	var arena: Node2D = (load("res://scenes/pvp_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().physics_frame

	var tm: TileMap = arena.find_child("TileMap", true, false) as TileMap
	if tm != null:
		print("PROBE tilemap: layers_count=%d pos=%s scale=%s" % [
			tm.get_layers_count(), str(tm.global_position), str(tm.scale)])
		print("PROBE tilemap: layer0 name=%s enabled=%s layer=%d mask=%d" % [
			tm.get_layer_name(0), str(tm.is_layer_enabled(0)),
			tm.get_layer_collision_enabled(0) if tm.has_method("get_layer_collision_enabled") else -1, -2])

	var space: PhysicsDirectSpaceState2D = arena.get_world_2d().direct_space_state
	for p in POINTS:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = p
		params.collision_mask = 0xFFFFFFFF
		params.collide_with_areas = false
		params.collide_with_bodies = true
		var hits: Array[Dictionary] = space.intersect_point(params, 8)
		var names: Array[String] = []
		for h in hits:
			var collider: Object = h.get("collider")
			if collider is Node:
				names.append("%s(%s)" % [(collider as Node).name, (collider as Node).get_class()])
		print("PROBE point %s -> %d hits: %s" % [str(p), hits.size(), ", ".join(names)])
	get_tree().quit()
