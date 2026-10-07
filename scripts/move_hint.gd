extends CanvasLayer

## One-shot "WASD to move" prompt. It greets the mole on the first spawn into the
## mole village - the opening scene of a new game - and never appears again, so
## walking back into the village or dying into it stays quiet.
##
## The flag lives in Progress and is written the moment the hint appears rather
## than when it is dismissed, so a quit before the player ever touches a key does
## not bring it back.
##
## The label is built here instead of in the scene file, the way Progress builds
## its acorn hub label, so the village carries one node rather than a CanvasLayer
## of theme overrides it only ever shows once.

const HINT_TEXT := "WASD TO MOVE"
const FONT_PATH := "res://Baby Doll.otf"

const FADE_IN := 0.35
const FADE_OUT := 0.3

## Held off long enough to cover the wipe that brought the village up - the
## circle's 0.8s plus the loading screen's minimum hold and fade - so a key
## still down from the menu that led here cannot dismiss the hint before it has
## ever been on screen. The same reason credits.gd holds its skip off for a
## moment after the roll starts.
const READY_GRACE := 1.8
## And it is a hint, not furniture: a player who never presses anything has it
## fade on its own rather than sit over the village for the whole visit.
const AUTO_DISMISS := 6.0

const HINT_COLOR := Color(0.4, 0.95, 1.0, 1.0)

var _label: Label = null
var _age := 0.0
var _dismissing := false

func _ready() -> void:
	if Progress.move_hint_seen:
		_dismissing = true
		queue_free()
		return
	Progress.mark_move_hint_seen()
	_build_label()
	_label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 1.0, FADE_IN)

func _build_label() -> void:
	_label = Label.new()
	_label.name = "Hint"
	_label.text = HINT_TEXT
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -300.0
	_label.offset_right = 300.0
	# Sits below the arrival banner, which owns the top strip for its first few
	# seconds in Mole Village - the one place both of them ever appear.
	_label.offset_top = 136.0
	_label.offset_bottom = 184.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", HINT_COLOR)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var font := load(FONT_PATH) as Font
	if font != null:
		_label.add_theme_font_override("font", font)
	add_child(_label)

func _process(delta: float) -> void:
	_age += delta
	if _dismissing:
		return
	if _age < READY_GRACE:
		return
	if _moved() or _age >= AUTO_DISMISS:
		_dismiss()

## Any of the four movement keys, read edge-triggered so a key still held from
## the menu that led here cannot count as a move on the first frame it sees.
func _moved() -> bool:
	return Input.is_action_just_pressed("ui_left") \
		or Input.is_action_just_pressed("ui_right") \
		or Input.is_action_just_pressed("ui_accept") \
		or Input.is_action_just_pressed("ui_down")

func _dismiss() -> void:
	_dismissing = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_label, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)
