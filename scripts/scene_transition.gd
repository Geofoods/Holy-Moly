extends CanvasLayer

## Circle wipe between scenes.
##
## The tree is held paused for the whole wipe, so the level being left isn't
## still running behind the closing circle and the level being entered isn't
## already animating behind the opening one. Only the wipe itself keeps
## processing, which is what PROCESS_MODE_ALWAYS on this node is for.

@onready var rect: ColorRect = $ColorRect

const WIPE_TIME := 0.8

var _shader_material: ShaderMaterial

func _ready() -> void:
	# The wipe has to keep animating while everything else is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := preload("res://shaders/circle_wipe.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("progress", 0.0)
	rect.material = _shader_material
	rect.modulate.a = 1.0

func change_to(path: String) -> void:
	if path.is_empty():
		queue_free()
		return
	get_tree().paused = true
	_shader_material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, WIPE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	if path.begins_with("res://scenes/level") or path == "res://scenes/tutorial.tscn" or path == "res://scenes/map.tscn":
		Inventory.current_level_path = path
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, WIPE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	# Always hand the tree back running. The scene just loaded manages its own
	# pause state, and a wipe can legitimately start from an already-paused
	# state - level_results auto-advances that way, and so does the boss finale.
	# Restoring whatever we found here would leave the incoming level frozen.
	get_tree().paused = false
	queue_free()

func _set_progress(value: float) -> void:
	_shader_material.set_shader_parameter("progress", value)
