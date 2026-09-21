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
	# The mole village is a surface area like level 1, so it stays lit the
	# same way instead of getting the cave shade campaign levels use.
	if path.ends_with("molevillage.tscn"):
		return
	if path.ends_with("win_screen.tscn") or path.ends_with("game_over.tscn"):
		return
	# The shopkeeper's room is lit by its own candles, so it never gets the
	# cave shade the campaign levels use.
	if path.ends_with("shopkeeper_item.tscn"):
		return
	if scene.get_node_or_null("AmbientModulate") == null:
		var cm := CanvasModulate.new()
		cm.name = "AmbientModulate"
		cm.color = AMBIENT
		scene.add_child(cm)