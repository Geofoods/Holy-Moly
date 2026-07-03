extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

var _shader_material: ShaderMaterial

func _ready() -> void:
	var shader := preload("res://shaders/circle_wipe.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("progress", 0.0)
	rect.material = _shader_material
	rect.modulate.a = 1.0

func change_to(path: String) -> void:
	_shader_material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	queue_free()

func _set_progress(value: float) -> void:
	_shader_material.set_shader_parameter("progress", value)
