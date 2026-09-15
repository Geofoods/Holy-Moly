extends CanvasLayer

const FONT_PATH := "res://Baby Doll.otf"

const COL_BG := Color(0.93, 0.85, 0.66, 1)
const COL_BORDER := Color(0.42, 0.28, 0.14, 1)
const COL_INNER_BG := Color(0.97, 0.91, 0.78, 1)
const COL_INNER_BORDER := Color(0.6, 0.44, 0.24, 0.6)
const COL_TEXT := Color(0.32, 0.2, 0.08, 1)
const COL_MUTED := Color(0.5, 0.4, 0.25, 1)
const COL_GOLD := Color(0.6, 0.42, 0.1, 1)
const COL_GREEN := Color(0.22, 0.5, 0.18, 1)
const COL_RED := Color(0.62, 0.2, 0.2, 1)
const COL_BTN := Color(0.8, 0.68, 0.46, 1)
const COL_BTN_HOT := Color(0.97, 0.91, 0.78, 1)

var _level_path := ""
var _start_ticks := 0
var _coins_before := 0
var _next_path := ""
var _retry_target := ""
var _last_level_name := ""

var _dim: ColorRect = null
var _panel: PanelContainer = null
var _closing := false

func begin_level() -> void:
	var cs = get_tree().current_scene
	if cs == null:
		return
	var path := str(cs.scene_file_path)
	if path.ends_with("map.tscn") or path.ends_with("intro.tscn") \
		or path.ends_with("game_over.tscn") or path.ends_with("win_screen.tscn") \
		or path.ends_with("tutorial.tscn") or path.ends_with("whack_a_mole.tscn"):
		return
	_level_path = path
	_start_ticks = Time.get_ticks_msec()
	_coins_before = Shop.coins
	ComboManager.begin_level()

func finish_level(next_path: String, opts: Dictionary = {}) -> void:
	var cs = get_tree().current_scene
	var path := str(cs.scene_file_path) if cs != null else ""
	var info := LevelData.get_info(path)
	if not opts.get("forced", false) and info.is_empty():
		_transition(next_path)
		return
	_show_overlay(next_path, opts)

func _show_overlay(next_path: String, opts: Dictionary) -> void:
	if _closing:
		return
	_next_path = next_path
	_retry_target = _level_path
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var cs = get_tree().current_scene
	var path := str(cs.scene_file_path) if cs != null else ""
	var info := LevelData.get_info(path)
	_last_level_name = str(opts.get("level_name", info.get("name", "Level Clear")))

	var elapsed := maxi(int((Time.get_ticks_msec() - _start_ticks) / 1000), 0)
	var coins_gained := maxi(Shop.coins - _coins_before, 0)
	var best_combo := ComboManager.get_level_best()
	var acorn_found := Progress.has_acorn(path)

	Progress.mark_level_complete(path)
	Progress.update_best_combo(best_combo)

	_build_ui(elapsed, coins_gained, best_combo, acorn_found)
	_play_open_anim()

func _build_ui(elapsed: int, coins_gained: int, best_combo: int, acorn_found: bool) -> void:
	var root := Control.new()
	root.name = "ResultsRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var theme := Theme.new()
	theme.default_font = load(FONT_PATH) as Font
	theme.default_font_size = 20
	root.theme = theme

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.clip_contents = true
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.add_theme_stylebox_override("panel", _make_style_box(COL_BG, COL_BORDER, 18, 5, true))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "LEVEL CLEAR!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_TEXT)
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = _last_level_name
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COL_MUTED)
	sub.add_theme_font_size_override("font_size", 22)
	vbox.add_child(sub)

	var content := PanelContainer.new()
	content.add_theme_stylebox_override("panel", _make_style_box(COL_INNER_BG, COL_INNER_BORDER, 12, 3))
	vbox.add_child(content)

	var rows_margin := MarginContainer.new()
	rows_margin.add_theme_constant_override("margin_left", 20)
	rows_margin.add_theme_constant_override("margin_right", 20)
	rows_margin.add_theme_constant_override("margin_top", 14)
	rows_margin.add_theme_constant_override("margin_bottom", 14)
	content.add_child(rows_margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows_margin.add_child(rows)

	_add_stat(rows, "Time", "%d:%02d" % [elapsed / 60, elapsed % 60])
	_add_stat(rows, "Coins collected", "+%d" % coins_gained, COL_GOLD)
	_add_stat(rows, "Best combo", "x%d" % best_combo)
	_add_stat(rows, _header("Golden Acorn"), "FOUND!" if acorn_found else "MISSED", COL_GREEN if acorn_found else COL_RED)
	_add_stat(rows, _header("Acorn total"), "%d / %d" % [Progress.acorn_count(), Progress.acorn_total])

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	vbox.add_child(buttons)

	var retry := _make_btn("RETRY (R)")
	retry.pressed.connect(func() -> void:
		_goto(_retry_target)
	)
	buttons.add_child(retry)

	var next := _make_btn("NEXT")
	next.pressed.connect(func() -> void:
		_goto(_next_path)
	)
	buttons.add_child(next)

	var hint := Label.new()
	hint.text = "R  retry    |    Enter  continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(hint)

func _header(text: String) -> String:
	return text

func _add_stat(rows: VBoxContainer, label_text: String, value: String, color: Color = COL_TEXT) -> void:
	var row := HBoxContainer.new()
	var name := Label.new()
	name.text = label_text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", COL_BODY)
	name.add_theme_font_size_override("font_size", 22)
	row.add_child(name)
	var val := Label.new()
	val.text = value
	val.add_theme_color_override("font_color", color)
	val.add_theme_font_size_override("font_size", 24)
	row.add_child(val)
	rows.add_child(row)

const COL_BODY := Color(0.2, 0.14, 0.06, 1)

func _make_style_box(bg: Color, border: Color, radius: int, border_width: int = 2, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_width)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 16
	return sb

func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 44)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", _make_style_box(COL_BTN, COL_BORDER, 8, 2))
	for state in ["hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, _make_style_box(COL_BTN_HOT, COL_BORDER, 8, 2))
	return btn

func _play_open_anim() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	_panel.resized.connect(func() -> void:
		_panel.pivot_offset = _panel.size / 2.0
	)
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if _closing or not is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_goto(_retry_target)
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_goto(_next_path)

func _goto(path_to: String) -> void:
	if _closing or path_to == "":
		return
	_closing = true
	get_tree().paused = false
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(path_to)
	queue_free()

func _transition(path_to: String) -> void:
	if path_to == "":
		return
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(path_to)