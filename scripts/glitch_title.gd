extends Control

const JITTER_MIN_INTERVAL := 0.05
const JITTER_MAX_INTERVAL := 0.18
const JITTER_AMOUNT := 4.0
const BIG_GLITCH_CHANCE := 0.08

var _time_to_next_jitter := 0.0

func _ready() -> void:
	_schedule_next()

func _process(delta: float) -> void:
	_time_to_next_jitter -= delta
	if _time_to_next_jitter <= 0.0:
		_apply_jitter()
		_schedule_next()

func _schedule_next() -> void:
	_time_to_next_jitter = randf_range(JITTER_MIN_INTERVAL, JITTER_MAX_INTERVAL)

func _apply_jitter() -> void:
	var red = $TitleRed
	var cyan = $TitleCyan
	var big := randf() < BIG_GLITCH_CHANCE
	var amount := JITTER_AMOUNT * (3.0 if big else 1.0)
	red.position = Vector2(randf_range(-amount, amount), randf_range(-amount * 0.3, amount * 0.3))
	cyan.position = Vector2(randf_range(-amount, amount), randf_range(-amount * 0.3, amount * 0.3))
	red.modulate.a = randf_range(0.35, 0.65)
	cyan.modulate.a = randf_range(0.35, 0.65)
