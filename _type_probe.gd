extends Node

## Temporary: reports the imported runtime type/format of the project's sounds.

func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func(): get_tree().quit(2))
	var s1: AudioStream = load("res://sounds/swing_1.wav")
	print("PROBE swing class=", s1.get_class())
	if s1 is AudioStreamWAV:
		var w := s1 as AudioStreamWAV
		print("PROBE swing format=", w.format, " rate=", w.mix_rate, " stereo=", w.stereo, " bytes=", w.data.size())
	var s2: AudioStream = load("res://sounds/break_stone_1.ogg")
	print("PROBE break class=", s2.get_class())
	var s3: AudioStream = load("res://sounds/drill.wav")
	print("PROBE drill class=", s3.get_class())
	if s3 is AudioStreamWAV:
		var w := s3 as AudioStreamWAV
		print("PROBE drill format=", w.format, " rate=", w.mix_rate, " stereo=", w.stereo)
	get_tree().quit(0)
