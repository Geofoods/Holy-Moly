extends Node

## TEMPORARY probe: dumps every painted cell span in the arena TileMap.

func _ready() -> void:
	await get_tree().process_frame
	var tm := find_child("TileMap", true, false) as TileMap
	if tm == null:
		print("DUMP: no TileMap node")
		get_tree().quit()
		return
	var rect := tm.get_used_rect()
	print("DUMP used_rect=", rect, " step=", Vector2(tm.tile_set.tile_size) * tm.scale)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		var cells: Array[Vector2i] = []
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if tm.get_cell_source_id(0, Vector2i(x, y)) != -1:
				cells.append(Vector2i(x, y))
		if cells.is_empty():
			continue
		var spans := []
		var start := cells[0]
		var prev := cells[0]
		for i in range(1, cells.size()):
			if cells[i].x != prev.x + 1:
				spans.append("%d..%d" % [start.x, prev.x])
				start = cells[i]
			prev = cells[i]
		spans.append("%d..%d" % [start.x, prev.x])
		var top := tm.to_global(tm.map_to_local(Vector2i(cells[0].x, y)))
		print("DUMP y=%d world_top=%.0f painted=%d spans=%s" % [y, top.y, cells.size(), ", ".join(spans)])
	get_tree().quit()
