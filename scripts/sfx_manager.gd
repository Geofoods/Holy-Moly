extends Node

var _sounds := {}
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []

const POOL_SIZE := 16

## The dry, near-silent reverb every level starts from, and the state anything
## outside a level falls back to.
##
## The effect itself is a master-bus effect, so it is global and outlives the
## scene that set it - without a reset, the echo of a deep cave level follows the
## player out to the menu and every other front end.
const REVERB_BASE_WET := 0.0
const REVERB_BASE_ROOM_SIZE := 0.1

## Puts the global bus reverb back to the dry baseline. Called on every scene
## change; a level going to another level re-tunes it for its own depth as soon
## as its mole is ready.
func reset_reverb() -> void:
	if AudioServer.get_bus_effect_count(0) == 0:
		return
	var reverb := AudioServer.get_bus_effect(0, 0) as AudioEffectReverb
	if reverb == null:
		return
	reverb.wet = REVERB_BASE_WET
	reverb.room_size = REVERB_BASE_ROOM_SIZE

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
	# Bake every short SFX to PCM up front: see pcm(). Done here at boot so the
	# cost is hidden behind the splash instead of landing mid-gameplay.
	for key in _sounds:
		var streams: Array = _sounds[key]
		for s in streams:
			pcm(s)

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
	player.stream = pcm(stream)
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
	# Sent to the SFX bus so the settings screen's sound-effects slider moves it.
	p.bus = &"SFX"
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
	player.stream = pcm(stream)
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
	# Sent to the SFX bus so the settings screen's sound-effects slider moves it.
	p.bus = &"SFX"
	return p

## Short SFX are baked to PCM once and cached. Starting a playback on an OGG
## stream instantiates the Vorbis decoder every single play - over a millisecond
## each, which the web build feels as a hitch (breaking a block plays one of
## these). A PCM stream's playback instantiation is nearly free. Long or looping
## streams keep their originals: baking those would trade memory for something
## started rarely.
const PCM_BAKE_MAX_SECONDS := 12.0

static var _pcm_cache := {}

static func pcm(stream: AudioStream) -> AudioStream:
	if stream == null or stream is AudioStreamWAV:
		return stream
	if "loop" in stream and stream.loop:
		return stream
	if stream.get_length() > PCM_BAKE_MAX_SECONDS:
		return stream
	var key := stream.get_instance_id()
	if _pcm_cache.has(key):
		return _pcm_cache[key]
	var baked := _bake_pcm(stream)
	if baked == null:
		return stream
	_pcm_cache[key] = baked
	return baked

static func _bake_pcm(stream: AudioStream) -> AudioStreamWAV:
	var playback := stream.instantiate_playback()
	if playback == null:
		return null
	# Pulling frames from an unstarted playback yields silence on some stream
	# types, so start it from the beginning before the bake pulls its frames.
	playback.start(0.0)
	# The old `playback.mix(buffer, scale, frames)` binding no longer exists on
	# every playback type (it errors on AudioStreamPlaybackOggVorbis); the
	# script-facing mixer is mix_audio(), which hands back a PackedVector2Array
	# of frames and optionally advances the position. The legacy call is kept
	# only as a fallback for engines that still expose it.
	var use_mix_audio := playback.has_method("mix_audio")
	var rate := 44100
	if "mix_rate" in stream:
		rate = int(stream.mix_rate)
	# A little slack over the nominal length: resampled streams can produce
	# slightly more frames than get_length() advertises.
	var total := int(ceil(stream.get_length() * float(rate))) + 256
	var floats := PackedFloat32Array()
	floats.resize(total * 2)
	var written := 0
	while written < total:
		var got := 0
		if use_mix_audio:
			var frames: PackedVector2Array = playback.mix_audio(1.0, 1024)
			got = frames.size()
			if got > total - written:
				frames.resize(total - written)
				got = frames.size()
			for i in range(got):
				var frame: Vector2 = frames[i]
				floats[written * 2] = frame.x
				floats[written * 2 + 1] = frame.y
		else:
			var chunk := PackedFloat32Array()
			chunk.resize(1024 * 2)
			got = int(playback.mix(chunk, 1.0, 1024))
			if got > total - written:
				got = total - written
			for i in range(got * 2):
				floats[written * 2 + i] = chunk[i]
		if got <= 0:
			break
		written += got
	if written == 0:
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = true
	var bytes := PackedByteArray()
	bytes.resize(written * 2 * 2)
	for i in range(written * 2):
		bytes.encode_s16(i * 2, int(clampf(floats[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	return wav

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
