extends Node

## TEMPORARY verification scaffold - delete after use.
## Stands in for "the heart has been beaten and the walk's track is up" by
## starting it from an autoload, which is _ready before the mole's own. The mole
## then calls LevelMusic.start() about a frame later, exactly as it does when the
## player really does walk in from the heart's arena.

func _ready() -> void:
	var path := str(get_tree().current_scene.scene_file_path)
	var music := get_node_or_null("/root/LevelMusic")
	if music == null or not path.contains("level_10"):
		return
	var inherited := OS.has_environment("VERIFY_INHERIT")
	if inherited:
		music._play_vessel_segment(0.0, 20.0, 0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var bed := music._player
	print("VERIFY[%s] bed_player=%s vessel_player=%s" % [
		"inherited" if inherited else "fresh",
		"ALIVE" if (bed != null and is_instance_valid(bed)) else "null",
		"ALIVE" if (music._vessel_player != null and is_instance_valid(music._vessel_player)) else "null",
	])