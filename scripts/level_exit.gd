extends Area2D

@export var target_scene: String = "res://scenes/level_06.tscn"
var _exit_sound := preload("res://seaeagle_music-sound-effect-in-the-cave-b-175810.mp3")
var _armed := false

func _ready() -> void:
	add_to_group("level_exit")
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

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("mole") or not _armed:
		return
	_play_exit_sound()
	_save_return_position(body)
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(target_scene)

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
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = _exit_sound
	player.volume_db = -6.0
	player.pitch_scale = 1.8
	get_tree().root.add_child(player)
	player.play()
	var tween := get_tree().create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(player, "volume_db", -40.0, 0.5)
	tween.tween_callback(player.queue_free)
