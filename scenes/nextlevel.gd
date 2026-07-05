extends Area2D

var _exit_sound := preload("res://seaeagle_music-sound-effect-in-the-cave-b-175810.mp3")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _get_next_scene() -> String:
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
		return "res://scenes/main.tscn"
	num += 1
	return "res://scenes/%s%02d.tscn" % [prefix, num]

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("mole"):
		return
	_play_exit_sound()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(_get_next_scene())

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
