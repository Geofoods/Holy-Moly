extends CanvasLayer

signal next_pressed

const TYPE_SPEED := 0.018
const PANEL_MARGIN_SIDE := 60.0
const PANEL_HEIGHT := 150.0
const PANEL_BOTTOM_OFFSET := 40.0

@onready var panel: PanelContainer = $Panel
@onready var step_label: Label = $Panel/MarginContainer/VBoxContainer/StepLabel
@onready var main_label: Label = $Panel/MarginContainer/VBoxContainer/MainLabel
@onready var next_button: Button = $Panel/MarginContainer/VBoxContainer/NextRow/NextButton

var _full_text := ""
var _type_tween: Tween
var _hidden_y := 0.0
var _shown_y := 0.0

func _ready() -> void:
	next_button.pressed.connect(func(): next_pressed.emit())
	
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(vp_size.x - PANEL_MARGIN_SIDE * 2.0, PANEL_HEIGHT)
	panel.position = Vector2(PANEL_MARGIN_SIDE, vp_size.y - PANEL_HEIGHT - PANEL_BOTTOM_OFFSET)

	_shown_y = panel.position.y
	_hidden_y = _shown_y + panel.size.y + 40.0
	panel.position.y = _hidden_y
	panel.modulate.a = 0.0

func show_text(text: String, step: int = 0, total: int = 0, show_next: bool = false) -> void:
	_full_text = text
	if total > 0:
		step_label.text = "TUTORIAL  •  STEP %d / %d" % [step, total]
		step_label.show()
	else:
		step_label.hide()
	next_button.visible = show_next
	main_label.text = ""

	var tween := create_tween()
	tween.tween_property(panel, "position:y", _shown_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.25)

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

func skip_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	main_label.text = _full_text

func hide_box() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "position:y", _hidden_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.25)
