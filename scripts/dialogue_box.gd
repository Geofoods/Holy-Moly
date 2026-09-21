extends CanvasLayer

signal next_pressed
signal prev_pressed

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

func _ready() -> void:
	next_button.pressed.connect(func():
		SFX.play_ui("ui_click")
		next_pressed.emit()
	)
	prev_button.pressed.connect(func():
		SFX.play_ui("ui_click")
		prev_pressed.emit()
	)

	# The panel sizes and positions itself from the scene (bottom-anchored, grows
	# upward with content), so the buttons are always visible. We only animate the
	# whole layer sliding in and fading.
	offset.y = SLIDE_DISTANCE
	panel.modulate.a = 0.0

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
	portrait.visible = texture != null
	portrait.texture = texture
	portrait.modulate = tint

func set_npc_name(text: String) -> void:
	name_label.visible = text != ""
	name_label.text = text

func skip_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	main_label.text = _full_text

func hide_box() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "offset:y", SLIDE_DISTANCE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
