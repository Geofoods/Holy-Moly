extends Node

## TEMPORARY probe #2: verify the inherited PvP player scene and the tilemap.

func _ready() -> void:
	await get_tree().process_frame
	var pvp_packed: PackedScene = load("res://scenes/pvp_player.tscn") as PackedScene
	if pvp_packed == null:
		print("PROBE bad: cannot load pvp_player.tscn")
		return
	var player := pvp_packed.instantiate() as Node2D
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("PROBE pvp_player class=%s script=%s" % [
		str(player.get_class()),
		str(player.get_script().resource_path if player.get_script() else "<none>")
	])
	if player.has_method("configure"):
		print("PROBE pvp_player has configure")
	else:
		print("PROBE pvp_player MISSING configure")
	player.queue_free()

	var arena: Node2D = (load("res://scenes/pvp_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().physics_frame
	var tm: TileMap = arena.find_child("TileMap", true, false) as TileMap
	if tm != null:
		print("PROBE arena tilemap: sources=%d layers=%d pos=%s" % [
			tm.tile_set.get_source_count(), tm.get_layers_count(), str(tm.global_position)])
	else:
		print("PROBE arena NO tilemap")
	get_tree().quit()
