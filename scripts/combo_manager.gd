extends CanvasLayer

const COMBO_WINDOW := 7.0
const SPEED_BONUS_PER_KILL := 0.03
const MAX_SPEED_BONUS := 0.25
const DAMAGE_BONUS_PER_KILL := 0.05
const MAX_DAMAGE_BONUS := 0.5
const COIN_BONUS_PER_KILL := 0.1
const MAX_COIN_BONUS := 1.0
const COYOTE_TIME := 0.08

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
	_label.offset_left = -320
	_label.offset_right = -20
	_label.offset_top = 90
	_label.offset_bottom = 450
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var font := load("res://Baby Doll.otf") as Font
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.visible = false
	_label.pivot_offset = Vector2(220, 30)
	add_child(_label)
	Inventory.player_died.connect(_on_player_died)

## The label sits on layer 100, above the game over screen, so a combo still
## counting down when the mole dies would sit on top of that art. Connected to
## the same signal the health HUD cracks on, which fires at the top of the death
## sequence (mole.gd) - well before the screen is up - so the label is gone by
## the time anything of it is on screen.
##
## Only the readout is hidden. The combo value itself is left alone: what it is
## worth on a retry is a separate question from whether it should be readable
## while the player is looking at a game over screen.
func _on_player_died() -> void:
	_kill_label_tweens()
	_label.visible = false

func _kill_label_tweens() -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_color_tween = null
	_scale_tween = null

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
	_combo_shake()
	_kill_hit_stop()

func get_speed_multiplier() -> float:
	if combo <= 0:
		return 1.0
	return 1.0 + minf(float(combo) * SPEED_BONUS_PER_KILL, MAX_SPEED_BONUS)

func get_coyote_time() -> float:
	return COYOTE_TIME

func get_damage_multiplier(target: Node = null) -> float:
	if target != null and is_instance_valid(target) and target.is_in_group(&"boss"):
		return 1.0
	return 1.0 + minf(float(combo) * DAMAGE_BONUS_PER_KILL, MAX_DAMAGE_BONUS)

func get_coin_multiplier() -> float:
	return 1.0 + minf(float(combo) * COIN_BONUS_PER_KILL, MAX_COIN_BONUS)

func _reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	_label.visible = false

func _update_label() -> void:
	var time_left := int(ceil(combo_timer))
	_label.text = "COMBO x%d\nDMG x%.2f\nCOIN x%.2f\nSPD x%.2f\nTIME %ds" % \
		[combo, get_damage_multiplier(), get_coin_multiplier(), get_speed_multiplier(), time_left]

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
	_kill_label_tweens()

	var target_color := _get_combo_color()
	_label.add_theme_color_override("font_color", Color.WHITE)
	_color_tween = create_tween()
	_color_tween.tween_property(_label, "theme_override_colors/font_color", target_color, 0.3)

	_label.scale = Vector2(1.3, 1.3)
	_scale_tween = create_tween()
	_scale_tween.tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _kill_hit_stop() -> void:
	if combo <= 1:
		return
	var mole = get_tree().get_first_node_in_group("mole")
	if not mole or not mole.has_method("hit_freeze"):
		return
	var freeze := 0.03 + 0.005 * minf(float(combo), 12.0)
	mole.hit_freeze(freeze)

func _combo_shake() -> void:
	var mole = get_tree().get_first_node_in_group("mole")
	if not mole or not mole.has_method("screen_shake"):
		return
	var intensity := 6.0
	var duration := 0.15
	if combo >= 10:
		intensity = 14.0; duration = 0.25
	elif combo >= 7:
		intensity = 10.0; duration = 0.2
	elif combo >= 5:
		intensity = 7.0; duration = 0.15
	elif combo >= 3:
		intensity = 4.0; duration = 0.1
	mole.screen_shake(intensity, duration)

func _play_combo_sound() -> void:
	var pitch := 0.8 + float(mini(combo, 12)) * 0.1
	var volume := -8.0 + float(mini(combo, 8)) * 0.5
	var stream := preload("res://combo sound mole.wav")
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	SFX.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
