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
	# Whatever the scene being left carried for itself is let go here rather than
	# on arrival, so a track like the village's fades out under the closing circle
	# instead of trailing into the level that comes next. The pause does not hold
	# this up: the fade lives on an autoload that always processes.
	#
	# Unless the level arriving wants that same track, in which case it is left
	# running and picked up again on arrival - see region_track_survives().
	if not LevelMusic.region_track_survives(path):
		LevelMusic.stop_region()
	_shader_material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, WIPE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	# The reverb rides on the master bus, so whatever a cave level set on it
	# outlives that level. Every scene change goes through here, so this is the
	# one place that has to clear it - a level that follows re-tunes it for its
	# own depth in the mole's _ready, and the menu and other front ends have no
	# mole, so they would otherwise keep echoing.
	SFX.reset_reverb()
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
