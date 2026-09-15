extends Node

const DEPTH_SHADER := preload("res://shaders/tilemap_depth.gdshader")

var _tracked_scene: Node = null

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _tracked_scene:
		return
	_tracked_scene = scene
	_apply_depth(scene)

func _apply_depth(scene: Node) -> void:
	var tilemaps := _find_tilemaps(scene)
	for tm in tilemaps:
		var rect := tm.get_used_rect()
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var tile_size := Vector2(float(tm.tile_set.tile_size.x), float(tm.tile_set.tile_size.y))
		var min_pos: Vector2 = Vector2(float(rect.position.x), float(rect.position.y)) * tile_size
		var max_pos: Vector2 = Vector2(float(rect.position.x + rect.size.x), float(rect.position.y + rect.size.y)) * tile_size
		var mat := ShaderMaterial.new()
		mat.shader = DEPTH_SHADER
		mat.set_shader_parameter("depth_min", min_pos)
		mat.set_shader_parameter("depth_max", max_pos)
		mat.set_shader_parameter("fade_start", 0.25)
		mat.set_shader_parameter("min_brightness", 0.22)
		tm.material = mat

func _find_tilemaps(node: Node) -> Array[TileMap]:
	var out: Array[TileMap] = []
	if node is TileMap:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_tilemaps(child))
	return out