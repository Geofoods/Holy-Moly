extends Node

func _ready() -> void:
	var overlay := get_node("/root/MapOverlay")
	overlay.open_map()
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_tmp_map_shot.png")
	print("saved ", img.get_width(), "x", img.get_height())
	get_tree().quit()
