extends Node2D

## Temporary benchmark for the block-break path. Deleted after use.
## Uncapped loop, ops paced every 20 frames so pooled reuse (chunk fade is 1.5s
## of engine time) actually appears in the windows. Calls the real code paths:
## TileBreakSFX and the real mole's spawn_dirt_particles.

const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

var tilemap: TileMap
var parent: Node2D
var mole: Node2D
var frame := 0
var phase := ""
var op_usec := 0
var last_ticks := 0
var frame_usec := 0

var samples := {}
var frames := {}

var cells := {}
var cursor := {}

var audio_stream: AudioStream
var break_ogg: AudioStream = preload("res://sounds/break_stone_1.ogg")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	get_tree().create_timer(120.0).timeout.connect(func():
		print("BENCH TIMEOUT")
		get_tree().quit(2))
	tilemap = TileMap.new()
	tilemap.tile_set = preload("res://tileset.tres")
	add_child(tilemap)
	parent = Node2D.new()
	add_child(parent)
	audio_stream = preload("res://sounds/break_stone_1.ogg")

	# The real mole: its spawn_dirt_particles is what a broken block calls.
	mole = preload("res://scenes/mole.tscn").instantiate()
	add_child(mole)
	mole.position = Vector2(8000, -200)

	for x in range(60):
		for y in range(60):
			tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 0))

	var regions := {
		"A_erase": [Vector2i(0, 0), Vector2i(9, 59)],
		"B_debris": [Vector2i(10, 0), Vector2i(19, 59)],
		"C_break": [Vector2i(20, 0), Vector2i(29, 59)],
	}
	for key in regions:
		var arr: Array[Vector2i] = []
		var r: Array = regions[key]
		for x in range((r[0] as Vector2i).x, (r[1] as Vector2i).x + 1):
			for y in range((r[0] as Vector2i).y, (r[1] as Vector2i).y + 1):
				arr.append(Vector2i(x, y))
		cells[key] = arr
		cursor[key] = 0

func _mark(name: String) -> void:
	phase = name
	if not samples.has(name):
		samples[name] = []
		frames[name] = []

func _sample() -> void:
	samples[phase].append(op_usec)
	frames[phase].append(frame_usec)

func _next_cell(key: String) -> Vector2i:
	var arr: Array = cells[key]
	var i: int = cursor[key]
	cursor[key] = i + 1
	return arr[i] if i < arr.size() else Vector2i(-99999, -99999)

func _tick(name: String) -> bool:
	# Marks the phase and samples on every 20th frame.
	if frame % 20 != 0:
		return false
	if phase != name:
		_mark(name)
	return true

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	frame_usec = now - last_ticks if last_ticks != 0 else 0
	last_ticks = now
	frame += 1
	op_usec = 0
	var t := 0

	# 0-149: warmup/idle baseline.
	if frame >= 50 and frame < 150 and frame % 20 == 0:
		if phase != "0_idle":
			_mark("0_idle")
		_sample()

	# A: bare erase_cell.
	if frame >= 150 and frame < 350 and _tick("A_erase"):
		var c := _next_cell("A_erase")
		t = Time.get_ticks_usec()
		tilemap.erase_cell(0, c)
		op_usec = Time.get_ticks_usec() - t
		_sample()

	# B_fresh: debris spawn with an empty chunk pool.
	if frame >= 400 and frame < 600 and _tick("B_fresh"):
		_spawn_debris()
		_sample()

	# F5/F6: PCM baking - first decode vs cached lookup (one shot each).
	if frame == 620:
		_mark("F5_bake")
		t = Time.get_ticks_usec()
		var baked: AudioStream = SFX.pcm(break_ogg)
		op_usec = Time.get_ticks_usec() - t
		_sample()
		var ok := baked is AudioStreamWAV and (baked as AudioStreamWAV).data.size() > 0
		var nonzero := 0
		if ok:
			var bytes: PackedByteArray = (baked as AudioStreamWAV).data
			for i in range(0, bytes.size(), 2):
				if bytes[i] != 0 or bytes[i + 1] != 0:
					nonzero += 1
		print("BENCH F5 baked_wav=%s bytes=%d nonzero_samples=%d" % [
			ok, (baked as AudioStreamWAV).data.size() if ok else 0, nonzero])
	if frame == 640:
		_mark("F6_cached")
		t = Time.get_ticks_usec()
		SFX.pcm(break_ogg)
		op_usec = Time.get_ticks_usec() - t
		_sample()

	# F7: play() on the baked PCM stream.
	if frame >= 660 and frame < 740 and _tick("F7_baked_play"):
		var p: AudioStreamPlayer2D = TileBreakSFX._acquire_player(parent)
		p.stream = SFX.pcm(break_ogg)
		p.pitch_scale = 1.0
		p.volume_db = -6.0
		p.global_position = Vector2(1000, 1000)
		t = Time.get_ticks_usec()
		p.play()
		op_usec = Time.get_ticks_usec() - t
		TileBreakSFX._release_player(p)
		_sample()

	# B_reuse: same call once the first window's chunks have faded into the pool.
	if frame >= 800 and frame < 1000 and _tick("B_reuse"):
		_spawn_debris()
		_sample()

	# F1/F2/F3: the audio path split into acquire / configure / play. Manual
	# release emulates `finished` (headless audio never emits it), so these are
	# the steady pooled costs.
	if frame >= 1100 and frame < 1180 and _tick("F1_acquire"):
		t = Time.get_ticks_usec()
		var p: AudioStreamPlayer2D = TileBreakSFX._acquire_player(parent)
		op_usec = Time.get_ticks_usec() - t
		TileBreakSFX._release_player(p)
		_sample()
	if frame >= 1200 and frame < 1280 and _tick("F2_config"):
		var p: AudioStreamPlayer2D = TileBreakSFX._acquire_player(parent)
		t = Time.get_ticks_usec()
		p.stream = audio_stream
		p.pitch_scale = 1.0
		p.volume_db = -6.0
		p.global_position = Vector2(1000, 1000)
		op_usec = Time.get_ticks_usec() - t
		TileBreakSFX._release_player(p)
		_sample()
	if frame >= 1300 and frame < 1380 and _tick("F3_play"):
		var p: AudioStreamPlayer2D = TileBreakSFX._acquire_player(parent)
		p.stream = audio_stream
		p.pitch_scale = 1.0
		p.volume_db = -6.0
		p.global_position = Vector2(1000, 1000)
		t = Time.get_ticks_usec()
		p.play()
		op_usec = Time.get_ticks_usec() - t
		TileBreakSFX._release_player(p)
		_sample()

	# F4: play() on a PCM (AudioStreamWAV) stream - does the OGG playback
	# instantiation account for the F3 cost?
	if frame >= 1400 and frame < 1480 and _tick("F4_wav_play"):
		var p: AudioStreamPlayer2D = TileBreakSFX._acquire_player(parent)
		p.stream = _wav_stream()
		p.pitch_scale = 1.0
		p.volume_db = -6.0
		p.global_position = Vector2(1000, 1000)
		t = Time.get_ticks_usec()
		p.play()
		op_usec = Time.get_ticks_usec() - t
		TileBreakSFX._release_player(p)
		_sample()

	# C_steady: full break_tile, paced like real digging.
	if frame >= 1500 and frame < 2100 and _tick("C_steady"):
		var c := _next_cell("C_break")
		t = Time.get_ticks_usec()
		TileBreakSFX.break_tile(tilemap, c, parent)
		op_usec = Time.get_ticks_usec() - t
		_sample()

	# D: burst of 20 break_tile in ONE frame (bomb / ground pound).
	if frame == 2200:
		_mark("D_burst")
		t = Time.get_ticks_usec()
		for i in range(20):
			TileBreakSFX.break_tile(tilemap, Vector2i(30 + i, 0), parent)
		op_usec = Time.get_ticks_usec() - t
		_sample()

	# E_dirt: the real mole's dirt burst (pooled ring).
	if frame >= 2400 and frame < 2700 and _tick("E_dirt"):
		t = Time.get_ticks_usec()
		mole.call("spawn_dirt_particles", Vector2(1000, 1000))
		op_usec = Time.get_ticks_usec() - t
		_sample()

	if frame == 2800:
		_report()
		get_tree().quit(0)

var _wav: AudioStreamWAV

func _wav_stream() -> AudioStreamWAV:
	if _wav != null:
		return _wav
	_wav = AudioStreamWAV.new()
	_wav.format = AudioStreamWAV.FORMAT_16_BITS
	_wav.mix_rate = 44100
	_wav.stereo = true
	var pcm := PackedByteArray()
	pcm.resize(int(0.3 * 44100) * 2 * 2) # 0.3s stereo int16 silence
	_wav.data = pcm
	return _wav

func _spawn_debris() -> void:
	var src: TileSetAtlasSource = tilemap.tile_set.get_source(0)
	var t := Time.get_ticks_usec()
	TileBreakSFX.spawn_texture_break_particles(
		src.texture,
		Rect2(Vector2(1, 0) * 160.0, Vector2(160, 160)),
		Vector2(15 * 160, 30 * 160), parent, 4, 18.0, 34.0, 3)
	op_usec = Time.get_ticks_usec() - t

func _report() -> void:
	for key in samples:
		var ops: Array = samples[key]
		var fms: Array = frames[key]
		var op_sum := 0
		var op_max := 0
		for v in ops:
			op_sum += int(v)
			op_max = maxi(op_max, int(v))
		var f_sum := 0
		var f_max := 0
		for v in fms:
			f_sum += int(v)
			f_max = maxi(f_max, int(v))
		var n := maxi(ops.size(), 1)
		print("BENCH %-10s n=%2d op_avg_us=%6d op_max_us=%6d frame_avg_us=%7d frame_max_us=%7d" % [
			key, ops.size(), op_sum / n, op_max, f_sum / n, f_max])
