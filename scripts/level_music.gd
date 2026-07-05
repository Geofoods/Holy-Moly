extends Node

var _player: AudioStreamPlayer = null
var _stream := preload("res://nojisuma-grotto-120967.mp3")
var _target_volume := -18.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start() -> void:
	if _player and is_instance_valid(_player):
		return
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.volume_db = _target_volume
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_player.play)
	_player.play()

func stop() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", -40.0, 1.0)
	tween.tween_callback(_player.queue_free)
	_player = null

func pause() -> void:
	if _player and is_instance_valid(_player) and _player.playing:
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", -40.0, 0.4)
		tween.tween_callback(_player.set.bind("stream_paused", true))

func resume() -> void:
	if _player and is_instance_valid(_player):
		_player.stream_paused = false
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", _target_volume, 0.4)

func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing
