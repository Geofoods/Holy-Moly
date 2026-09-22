extends AnimatedSprite2D

## Holds a resting frame and fires the blink animation at random intervals.

@export var blink_animation := "blink"
@export var rest_frame := 0
@export var min_interval := 1.0
@export var max_interval := 3.0

var _timer := 0.0

func _ready() -> void:
	if sprite_frames and sprite_frames.has_animation(blink_animation):
		animation = blink_animation
		# Play-once so the blink doesn't loop; we park on rest_frame between blinks.
		sprite_frames.set_animation_loop(blink_animation, false)
	stop()
	frame = rest_frame
	animation_finished.connect(_on_blink_finished)
	_reset_timer()

func _reset_timer() -> void:
	_timer = randf_range(min_interval, max_interval)

func _process(delta: float) -> void:
	if is_playing():
		return
	_timer -= delta
	if _timer <= 0.0:
		_reset_timer()
		if sprite_frames and sprite_frames.has_animation(blink_animation):
			play(blink_animation)

func _on_blink_finished() -> void:
	stop()
	frame = rest_frame
