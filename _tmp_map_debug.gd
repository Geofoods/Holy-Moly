extends Node

func _ready() -> void:
	var overlay := get_node("/root/MapOverlay")
	overlay.open_map()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "C:/Users/curio/AppData/Local/Temp/opencode/_tmp_map.png"
	var err := img.save_png(path)
	print("SAVED ", img.get_size(), " err=", err, " path=", path)
	get_tree().quit()
