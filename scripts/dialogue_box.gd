extends CanvasLayer

signal next_pressed
signal prev_pressed

## How many dialogue boxes are currently live. Every one of them owns the screen
## while it is up, so this is the single answer to "is the player reading rather
## than playing". A count rather than a flag because a box is freed some time
## after it closes, so the flag would stay set through the fade-out.
static var _open_count := 0

## True while any dialogue box is on screen. The mole checks this so items
## cannot be fired or spent mid-conversation. These checks cannot lean on
## get_tree().paused: NPC conversations deliberately leave the tree running so
## explosions and particles keep going under the box.
static func is_open() -> bool:
	return _open_count > 0

## Keeps the music in step with the boxes. Driven off the same count that
## `is_open()` reads, and only acts on the 0-1 and 1-0 edges: a second box opening
## while the first is still sliding away must not start the music back up
## underneath it.
static func _follow_music() -> void:
	if _open_count > 0:
		LevelMusic.duck_for_dialogue()
	else:
		LevelMusic.unduck_for_dialogue()

const TYPE_SPEED := 0.018
const SLIDE_DISTANCE := 240.0

@onready var panel: PanelContainer = $Panel
@onready var step_label: Label = $Panel/MarginContainer/VBoxContainer/StepLabel
@onready var name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var portrait: TextureRect = $Panel/MarginContainer/VBoxContainer/ContentRow/Portrait
@onready var main_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ContentRow/MainLabel
@onready var next_button: Button = $Panel/MarginContainer/VBoxContainer/NextRow/NextButton
@onready var prev_button: Button = $Panel/MarginContainer/VBoxContainer/NextRow/PrevButton

var _full_text := ""
var _type_tween: Tween
var _closing := false

# Optional idle-blink for the portrait: parks on a rest frame and plays the
# frame list through at random intervals, mirroring the NPC's own blink.
var _portrait_frames: Array = []
var _portrait_rest := 0
var _portrait_fps := 5.0
var _portrait_min := 1.0
var _portrait_max := 3.0
var _portrait_timer := 0.0
var _portrait_index := 0
var _portrait_frame_time := 0.0
var _portrait_playing := false

func _ready() -> void:
	_open_count += 1
	_follow_music()
	next_button.pressed.connect(_on_next_pressed)
	prev_button.pressed.connect(_on_prev_pressed)

	# The panel sizes and positions itself from the scene (bottom-anchored, grows
	# upward with content), so the buttons are always visible. We only animate the
	# whole layer sliding in and fading.
	offset.y = SLIDE_DISTANCE
	panel.modulate.a = 0.0

## Interact doubles as the continue/close key, so the box can be dismissed
## without reaching for the mouse.
func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_next_pressed()

func _on_next_pressed() -> void:
	SFX.play_ui("ui_click")
	next_pressed.emit()

func _on_prev_pressed() -> void:
	SFX.play_ui("ui_click")
	prev_pressed.emit()

func show_text(text: String, step: int = 0, total: int = 0, show_next: bool = false, show_prev: bool = false) -> void:
	_full_text = text
	if total > 0:
		step_label.text = "TUTORIAL  •  STEP %d / %d" % [step, total]
		step_label.show()
	else:
		step_label.hide()
	next_button.visible = show_next
	prev_button.visible = show_prev
	main_label.text = ""

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "offset:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)

	_type_text()

func _type_text() -> void:
	if _type_tween:
		_type_tween.kill()
	main_label.text = ""
	var count := _full_text.length()
	_type_tween = create_tween()
	_type_tween.tween_method(_set_typed_length, 0, count, count * TYPE_SPEED)

func _set_typed_length(length: int) -> void:
	main_label.text = _full_text.substr(0, length)

func set_portrait(texture: Texture2D, tint: Color = Color.WHITE) -> void:
	_portrait_frames = []
	_portrait_playing = false
	portrait.visible = texture != null
	portrait.texture = texture
	portrait.modulate = tint

## Give the portrait the same blink cycle the NPC sprite uses. `frames` is the
## ordered texture list of the blink animation; it rests on `rest_frame` and
## plays through every `min_interval`-`max_interval` seconds.
func set_portrait_animation(frames: Array, min_interval := 1.0, max_interval := 3.0, rest_frame := 0, fps := 5.0) -> void:
	_portrait_frames = frames
	if _portrait_frames.is_empty():
		return
	_portrait_rest = clampi(rest_frame, 0, _portrait_frames.size() - 1)
	_portrait_fps = maxf(fps, 0.01)
	_portrait_min = min_interval
	_portrait_max = max_interval
	_portrait_playing = false
	_portrait_index = _portrait_rest
	portrait.visible = true
	portrait.texture = _portrait_frames[_portrait_rest]
	_reset_portrait_timer()

func _reset_portrait_timer() -> void:
	_portrait_timer = randf_range(_portrait_min, _portrait_max)

func _process(delta: float) -> void:
	if _portrait_frames.is_empty():
		return
	if not _portrait_playing:
		_portrait_timer -= delta
		if _portrait_timer <= 0.0:
			_reset_portrait_timer()
			_portrait_playing = true
			_portrait_index = 0
			_portrait_frame_time = 0.0
			portrait.texture = _portrait_frames[0]
		return
	_portrait_frame_time += delta
	while _portrait_frame_time >= 1.0 / _portrait_fps:
		_portrait_frame_time -= 1.0 / _portrait_fps
		_portrait_index += 1
		if _portrait_index >= _portrait_frames.size():
			_portrait_playing = false
			_portrait_index = _portrait_rest
			break
	portrait.texture = _portrait_frames[_portrait_index]

func set_npc_name(text: String) -> void:
	name_label.visible = text != ""
	name_label.text = text

func skip_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	main_label.text = _full_text

## Releasing the count on the way out rather than on free keeps item use blocked
## through the slide-away, so the player cannot spend something in the moment
## between dismissing the box and it being gone.
func hide_box() -> void:
	_closing = true
	_open_count = maxi(_open_count - 1, 0)
	_follow_music()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "offset:y", SLIDE_DISTANCE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)

## A box can also disappear without hide_box - a scene change mid-line, or the
## husked NPC path that never opened one - so the count is released here too and
## cannot be left stuck above zero.
func _exit_tree() -> void:
	if not _closing:
		_open_count = maxi(_open_count - 1, 0)
		_follow_music()
