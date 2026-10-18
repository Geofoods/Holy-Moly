extends Node
func _ready() -> void:
	for path in ["res://scenes/pvp_player.tscn", "res://_test_a.tscn"]:
		var ps = load(path) as PackedScene
		if ps == null:
			print("LOAD FAIL ", path)
			continue
		var n = ps.instantiate()
		print("LOAD OK ", path, " root_class=", n.get_class(), " script=", str(n.get_script().resource_path if n.get_script() else "<none>"), " has_configure=", n.has_method("configure"), " children=", n.get_child_count())
		for c in n.get_children():
			print("   child: ", c.name, " ", c.get_class())
		n.free()
	get_tree().quit()
