extends Node

func _ready() -> void:
	var overlay := get_node("/root/MapOverlay")
	overlay.open_map()
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var panel: Control = null
	var mapbox: Control = null
	for c in overlay.get_children():
		_dump(c, 0)
	print("VIEWPORT ", vp)
	get_tree().quit()

func _dump(node: Node, depth: int) -> void:
	for c in node.get_children():
		if c is Control:
			print("  ".repeat(depth), c.get_class(), " size=", c.size)
		_dump(c, depth + 1)
