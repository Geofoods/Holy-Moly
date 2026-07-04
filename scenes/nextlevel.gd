extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _get_next_scene() -> String:
	var path := get_tree().current_scene.scene_file_path
	var filename := path.get_file()
	var prefix := "level_"
	if not filename.begins_with(prefix):
		return "res://scenes/level_02.tscn"
	var num_str := filename.trim_prefix(prefix).trim_suffix(".tscn")
	var num := num_str.to_int()
	if num_str.is_empty() or num <= 0:
		return "res://scenes/level_02.tscn"
	if num >= 9:
		return "res://scenes/main.tscn"
	num += 1
	return "res://scenes/%s%02d.tscn" % [prefix, num]

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("mole"):
		return
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(_get_next_scene())
