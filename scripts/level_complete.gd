extends CanvasLayer

## The screen shown once a portal has taken the mole.
##
## It is shared by the Level Editor's playtest and by a community level played
## from the browser. The host decides what CONTINUE does -- return to editing or
## leave for the browser -- so the screen only announces the finish and emits
## `continued`. The tree is paused while it is up, which keeps the level behind it
## still and stops the pause menu from fighting it for the screen.

signal continued

const FONT_PATH := "res://Baby Doll.otf"

const COL_BG := Color(0.93, 0.85, 0.66, 1)
const COL_BORDER := Color(0.42, 0.28, 0.14, 1)
const COL_INNER_BG := Color(0.97, 0.91, 0.78, 1)
const COL_INNER_BORDER := Color(0.6, 0.44, 0.24, 0.6)
const COL_TEXT := Color(0.32, 0.2, 0.08, 1)
const COL_MUTED := Color(0.5, 0.4, 0.25, 1)
const COL_GREEN := Color(0.18, 0.52, 0.24, 1)
const COL_GREEN_DARK := Color(0.08, 0.28, 0.12, 1)
const COL_BTN := Color(0.36, 0.66, 0.36, 1)
const COL_BTN_HOT := Color(0.48, 0.82, 0.48, 1)
const COL_BTN_TEXT := Color(0.98, 0.96, 0.86, 1)

var _dim: ColorRect = null
var _panel: PanelContainer = null
var _kicker: Label = null
var _title: Label = null
var _level_label: Label = null
var _button: Button = null
var _hint: Label = null
var _closing := false


func _ready() -> void:
	# The tree is paused while this screen is up, so every part of it -- including
	# its tweens and the button -- has to keep processing through the pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	visible = false
	_build()
	_button.pressed.connect(_on_continue_pressed)
	_button.mouse_entered.connect(_on_button_hover)


## Shows the screen for `level_name`. `button_text` lets each host name the way
## out in its own words -- BACK TO EDITING in the editor, CONTINUE in the browser.
func show_complete(level_name: String, button_text: String = "CONTINUE") -> void:
	if visible:
		return
	_closing = false
	_button.disabled = false
	_level_label.text = level_name if not level_name.strip_edges().is_empty() else "Untitled Level"
	_button.text = button_text
	visible = true
	get_tree().paused = true

	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	_title.modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.26)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "modulate:a", 1.0, 0.3).set_delay(0.08)
	_button.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	if _closing:
		return
	_closing = true
	_button.disabled = true
	SFX.play_ui("ui_click", -6.0, 1.2)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.18)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.18)
	await tween.finished
	visible = false
	# The screen is the thing that paused the tree, so it is the thing that lets
	# it go again before the host starts its own transition or rebuild.
	get_tree().paused = false
	continued.emit()


func _on_button_hover() -> void:
	if _button.disabled:
		return
	SFX.play_ui("ui_hover", -18.0, 1.8)


# ----------------------------------------------------------------------- build

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var theme := Theme.new()
	theme.default_font = load(FONT_PATH) as Font
	theme.default_font_size = 20
	root.theme = theme

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.01, 0.05, 0.02, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.clip_contents = true
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(560.0, 0.0)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_kicker = Label.new()
	_kicker.text = "PORTAL REACHED"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.add_theme_color_override("font_color", COL_GREEN)
	_kicker.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_kicker)

	_title = Label.new()
	_title.name = "TitleLabel"
	_title.text = "LEVEL COMPLETE!"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", COL_GREEN_DARK)
	_title.add_theme_font_size_override("font_size", 44)
	vbox.add_child(_title)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.text = "Untitled Level"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_color_override("font_color", COL_MUTED)
	_level_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_level_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	vbox.add_child(spacer)

	var content := PanelContainer.new()
	content.add_theme_stylebox_override("panel",
			_make_style_box(COL_INNER_BG, COL_INNER_BORDER, 12, 3))
	vbox.add_child(content)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 22)
	content_margin.add_theme_constant_override("margin_right", 22)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content.add_child(content_margin)

	var message := Label.new()
	message.text = "The portal carried you safely home."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", COL_TEXT)
	message.add_theme_font_size_override("font_size", 21)
	content_margin.add_child(message)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 10.0)
	vbox.add_child(gap)

	_button = Button.new()
	_button.name = "ContinueButton"
	_button.text = "CONTINUE"
	_button.custom_minimum_size = Vector2(300.0, 60.0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.focus_mode = Control.FOCUS_ALL
	_button.add_theme_font_size_override("font_size", 27)
	_button.add_theme_color_override("font_color", COL_BTN_TEXT)
	_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_button.add_theme_color_override("font_focus_color", Color.WHITE)
	_button.add_theme_color_override("font_pressed_color", COL_BTN_TEXT)
	_button.add_theme_stylebox_override("normal", _make_style_box(COL_BTN, COL_BORDER, 10, 3))
	_button.add_theme_stylebox_override("hover", _make_style_box(COL_BTN_HOT, COL_BORDER, 10, 3))
	_button.add_theme_stylebox_override("focus", _make_style_box(COL_BTN_HOT, COL_BORDER, 10, 3))
	_button.add_theme_stylebox_override("pressed", _make_style_box(COL_BTN, COL_BORDER, 10, 3))
	_button.add_theme_stylebox_override("disabled", _make_style_box(COL_BTN, COL_BORDER, 10, 3))
	vbox.add_child(_button)

	_hint = Label.new()
	_hint.text = "ENTER / SPACE / ESC"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", COL_MUTED)
	_hint.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_hint)


func _panel_style() -> StyleBoxFlat:
	var style := _make_style_box(COL_BG, COL_BORDER, 18, 5)
	style.shadow_color = Color(0.18, 0.62, 0.28, 0.38)
	style.shadow_size = 20
	return style


func _make_style_box(colour: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
