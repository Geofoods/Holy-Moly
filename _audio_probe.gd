extends Node

## Temporary: measures AudioStreamPlayer.play() cost with the REAL audio driver
## (windowed run) for OGG vs pre-made PCM, to confirm the headless numbers.

func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(func():
		print("PROBE TIMEOUT")
		get_tree().quit(2))
	var ogg: AudioStream = preload("res://sounds/break_stone_1.ogg")
	var wav: AudioStreamWAV = preload("res://sounds/swing_1.wav")
	# Let the audio driver come up first.
	await get_tree().create_timer(1.0).timeout
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	add_child(player)
	var t := 0
	var ogg_sum := 0
	var ogg_max := 0
	for i in range(50):
		player.stream = ogg
		t = Time.get_ticks_usec()
		player.play()
		var d := Time.get_ticks_usec() - t
		ogg_sum += d
		ogg_max = maxi(ogg_max, d)
		player.stop()
	var wav_sum := 0
	var wav_max := 0
	for i in range(50):
		player.stream = wav
		t = Time.get_ticks_usec()
		player.play()
		var d := Time.get_ticks_usec() - t
		wav_sum += d
		wav_max = maxi(wav_max, d)
		player.stop()
	print("PROBE ogg_play_avg_us=%d ogg_max_us=%d wav_play_avg_us=%d wav_max_us=%d" % [
		ogg_sum / 50, ogg_max, wav_sum / 50, wav_max])
	get_tree().quit(0)
