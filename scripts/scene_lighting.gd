extends Node

const AMBIENT := Color(0.42, 0.42, 0.48, 1.0)

var _tracked_scene: Node = null

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _tracked_scene:
		return
	_tracked_scene = scene
	var path := str(scene.scene_file_path)
	if path.ends_with("intro.tscn") or path.ends_with("level1.tscn"):
		return
	if path.ends_with("win_screen.tscn") or path.ends_with("game_over.tscn"):
		return
	if scene.get_node_or_null("AmbientModulate") == null:
		var cm := CanvasModulate.new()
		cm.name = "AmbientModulate"
		cm.color = AMBIENT
		scene.add_child(cm)