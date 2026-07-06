extends Node

var _sounds := {}
var _pool := []
var _pool_index := 0
const POOL_SIZE := 12

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

	_build_pool()

func _load(key: String, paths: Array) -> void:
	var streams: Array[AudioStream] = []
	for p in paths:
		var s = load(p)
		if s:
			streams.append(s)
	_sounds[key] = streams

func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 2000.0
		p.finished.connect(_return_to_pool.bind(p))
		add_child(p)
		_pool.append(p)

func _return_to_pool(player: AudioStreamPlayer2D) -> void:
	player.stop()

func play(key: String, pos: Vector2 = Vector2.ZERO, volume_db: float = -6.0, pitch_variation: float = 0.1) -> void:
	if not _sounds.has(key) or _sounds[key].size() == 0:
		return
	var streams: Array = _sounds[key]
	var stream: AudioStream = streams[randi() % streams.size()]

	var player: AudioStreamPlayer2D = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.global_position = pos
	player.play()

func play_ui(key: String, volume_db: float = -8.0, pitch: float = 1.0) -> void:
	if not _sounds.has(key) or _sounds[key].size() == 0:
		return
	var streams: Array = _sounds[key]
	var stream: AudioStream = streams[randi() % streams.size()]
	var player: AudioStreamPlayer2D = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = Vector2.ZERO
	player.play()
