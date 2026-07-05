extends CanvasLayer

const COMBO_WINDOW := 7.0
const SPEED_BONUS_PER_KILL := 0.08
const MAX_SPEED_BONUS := 0.6
const COYOTE_BASE := 0.08
const COYOTE_BONUS_PER_KILL := 0.02
const COYOTE_MAX := 0.2

var combo := 0
var combo_timer := 0.0

var _label: Label = null
var _color_tween: Tween = null
var _scale_tween: Tween = null

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.name = "ComboLabel"
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -220
	_label.offset_right = -20
	_label.offset_top = 75
	_label.offset_bottom = 135
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var font := load("res://Baby Doll.otf") as Font
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.visible = false
	_label.pivot_offset = Vector2(200, 30)
	add_child(_label)

func _process(delta: float) -> void:
	if combo <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		_reset_combo()
		return
	_update_label()

func increment() -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	_label.visible = true
	_play_combo_sound()
	_flash_label()
	_update_label()

func get_speed_multiplier() -> float:
	if combo <= 0:
		return 1.0
	return 1.0 + minf(float(combo) * SPEED_BONUS_PER_KILL, MAX_SPEED_BONUS)

func get_coyote_time() -> float:
	if combo <= 0:
		return COYOTE_BASE
	return minf(COYOTE_BASE + float(combo) * COYOTE_BONUS_PER_KILL, COYOTE_MAX)

func _reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	_label.visible = false

func _update_label() -> void:
	var time_left := int(ceil(combo_timer))
	_label.text = "COMBO x%d\n%ds" % [combo, time_left]

func _get_combo_color() -> Color:
	if combo >= 10:
		return Color(1.0, 0.2, 0.9)
	elif combo >= 7:
		return Color(1.0, 0.1, 0.1)
	elif combo >= 5:
		return Color(1.0, 0.5, 0.0)
	elif combo >= 3:
		return Color(1.0, 0.9, 0.0)
	else:
		return Color(0.4, 1.0, 0.4)

func _flash_label() -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()

	var target_color := _get_combo_color()
	_label.add_theme_color_override("font_color", Color.WHITE)
	_color_tween = create_tween()
	_color_tween.tween_property(_label, "theme_override_colors/font_color", target_color, 0.3)

	_label.scale = Vector2(1.3, 1.3)
	_scale_tween = create_tween()
	_scale_tween.tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_combo_sound() -> void:
	var pitch := 0.8 + float(mini(combo, 12)) * 0.1
	var volume := -8.0 + float(mini(combo, 8)) * 0.5
	var stream := preload("res://combo sound mole.wav")
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	SFX.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
