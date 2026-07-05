extends Area2D

@export var target_scene: String = "res://scenes/level_06.tscn"
var _exit_sound := preload("res://seaeagle_music-sound-effect-in-the-cave-b-175810.mp3")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("mole"):
		return
	_play_exit_sound()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(target_scene)

func _play_exit_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _exit_sound
	player.volume_db = -6.0
	player.pitch_scale = 1.8
	get_tree().root.add_child(player)
	player.play()
	# Auto-stop after 2 seconds (cut the tail) and fade out
	var tween := get_tree().create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(player, "volume_db", -40.0, 0.5)
	tween.tween_callback(player.queue_free)
