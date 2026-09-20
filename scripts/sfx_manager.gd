extends Node

var _sounds := {}
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []

const POOL_SIZE := 16

func _ready() -> void:
	_load("swing", ["res://sounds/swing_1.wav", "res://sounds/swing_2.wav", "res://sounds/swing_3.wav"])
	_load("hurt", ["res://sounds/hurt_1.ogg", "res://sounds/hurt_2.ogg"])
	_load("death", ["res://sounds/death.ogg"])
	_load("jump", ["res://sounds/jump_1.wav", "res://sounds/jump_2.wav"])
	_load("land", ["res://sounds/land.ogg"])
	_load("enemy_hit", ["res://sounds/enemy_hit_1.ogg", "res://sounds/enemy_hit_2.ogg", "res://sounds/enemy_hit_3.ogg"])
	_load("enemy_death", ["res://sounds/enemy_death_1.ogg", "res://sounds/enemy_death_2.ogg"])
	_load("enemy_fire", ["res://sounds/enemy_fire.ogg"])
	_load("explosion", ["res://sounds/explosion_1.ogg", "res://sounds/explosion_2.ogg"])
	_load("item_pickup", ["res://sounds/item_pickup.ogg"])
	_load("chest_open", ["res://sounds/chest_open.ogg"])
	_load("heal", ["res://sounds/heal.ogg"])
	_load("dig_dash", ["res://sounds/dig_dash.ogg"])
	_load("parry_activate", ["res://sounds/parry_activate.ogg"])
	_load("coin", ["res://sounds/coin.ogg"])
	_load("ui_click", ["res://sounds/ui_click.ogg"])
	_load("ui_hover", ["res://sounds/coin.ogg"])
	_load("break_wood", ["res://sounds/break_wood_1.ogg", "res://sounds/break_wood_2.ogg", "res://sounds/break_wood_3.ogg"])
	_load("drill", ["res://sounds/drill.wav"])
	_load("bomb_tick", ["res://sounds/bomb_tick.wav"])

func _load(key: String, paths: Array) -> void:
	var streams: Array[AudioStream] = []
	for p in paths:
		var s = load(p)
		if s:
			streams.append(s)
	_sounds[key] = streams

## `pitch_variation` is a +/- ratio applied around `pitch` (0.1 = +/-10%).
## `pitch` is an absolute multiplier (2.0 = one octave up).
func play(key: String, pos: Vector2 = Vector2.ZERO, volume_db: float = -6.0, pitch_variation: float = 0.1, pitch: float = 1.0) -> void:
	if not _sounds.has(key) or _sounds[key].size() == 0:
		return
	var streams: Array = _sounds[key]
	var stream: AudioStream = streams[randi() % streams.size()]
	var player := _acquire_2d()
	player.stream = stream
	player.volume_db = volume_db
	# Godot rejects pitch_scale <= 0, so keep the variation below 1.0: that
	# guarantees the lowest reachable pitch stays above zero.
	var variation := clampf(absf(pitch_variation), 0.0, 0.9)
	player.pitch_scale = maxf(0.01, pitch) * randf_range(1.0 - variation, 1.0 + variation)
	player.max_distance = 2000.0
	add_child(player)
	player.global_position = pos
	player.play()

func _acquire_2d() -> AudioStreamPlayer2D:
	var p: AudioStreamPlayer2D
	if _pool_2d.is_empty():
		p = AudioStreamPlayer2D.new()
		p.finished.connect(_release_2d.bind(p))
	else:
		p = _pool_2d.pop_back()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	return p

func _release_2d(p: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(p):
		return
	p.stop()
	p.stream = null
	if p.get_parent() == self and _pool_2d.size() < POOL_SIZE:
		remove_child(p)
		_pool_2d.append(p)
	else:
		p.queue_free()

func play_ui(key: String, volume_db: float = -8.0, pitch: float = 1.0) -> void:
	if not _sounds.has(key) or _sounds[key].size() == 0:
		return
	var streams: Array = _sounds[key]
	var stream: AudioStream = streams[randi() % streams.size()]
	var player := _acquire_ui()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.01, pitch)
	add_child(player)
	player.play()

func _acquire_ui() -> AudioStreamPlayer:
	var p: AudioStreamPlayer
	if _pool_ui.is_empty():
		p = AudioStreamPlayer.new()
		p.finished.connect(_release_ui.bind(p))
	else:
		p = _pool_ui.pop_back()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	return p

func _release_ui(p: AudioStreamPlayer) -> void:
	if not is_instance_valid(p):
		return
	p.stop()
	p.stream = null
	if p.get_parent() == self and _pool_ui.size() < POOL_SIZE:
		remove_child(p)
		_pool_ui.append(p)
	else:
		p.queue_free()
