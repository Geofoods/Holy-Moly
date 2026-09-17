extends Area2D

## Optional destination scene. Leave empty to automatically advance to the next
## numbered level scene (e.g. level_03.tscn -> level_04.tscn).
@export_file("*.tscn") var next_scene: String = ""

var _exit_sound := preload("res://seaeagle_music-sound-effect-in-the-cave-b-175810.mp3")
var _armed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_arm_after_settle()

## Ignore the mole if it starts the level already inside the zone (e.g. because
## it re-entered the level at its previous exit position). The zone only becomes
## active again once the mole leaves and deliberately walks back in.
func _arm_after_settle() -> void:
	# Wait for physics to settle so the initial overlap (if the mole spawned
	# inside) has been registered before deciding whether to arm.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_armed = not _mole_overlapping()

func _mole_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("mole"):
			return true
	return false

func _get_next_scene() -> String:
	if not next_scene.is_empty():
		return next_scene
	var path := get_tree().current_scene.scene_file_path
	var filename := path.get_file()
	var prefix := "level_"
	if not filename.begins_with(prefix):
		return "res://scenes/level_02.tscn"
	var num_str := filename.trim_prefix(prefix).trim_suffix(".tscn")
	var num := num_str.to_int()
	if num_str.is_empty() or num <= 0:
		return "res://scenes/level_02.tscn"
	if num >= 9:
		return "res://scenes/level1.tscn"
	num += 1
	return "res://scenes/%s%02d.tscn" % [prefix, num]

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("mole") or not _armed:
		return
	_play_exit_sound()
	_save_return_position(body)
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(_get_next_scene())

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_armed = true

func _save_return_position(body: Node) -> void:
	var cs := get_tree().current_scene
	if cs == null or not (body is Node2D):
		return
	Inventory.set_level_return_position(cs.scene_file_path, (body as Node2D).global_position)

func _play_exit_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _exit_sound
	player.volume_db = -6.0
	player.pitch_scale = 1.8
	SFX.add_child(player)
	player.play()
	var tween := SFX.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(player, "volume_db", -40.0, 0.5)
	tween.tween_callback(player.queue_free)
