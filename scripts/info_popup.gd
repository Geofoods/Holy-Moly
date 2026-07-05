extends CanvasLayer

const DANGER_LABELS := ["", "LOW", "MILD", "MODERATE", "HIGH", "EXTREME"]
const DANGER_COLORS := [
	Color.WHITE,
	Color(0.25, 0.65, 0.3, 1),
	Color(0.55, 0.65, 0.15, 1),
	Color(0.85, 0.55, 0.1, 1),
	Color(0.8, 0.25, 0.15, 1),
	Color(0.55, 0.1, 0.1, 1),
]

@onready var dim_background: ColorRect = $DimBackground
@onready var panel: Control = $CenterContainer/Panel
@onready var bestiary_tab: Button = $CenterContainer/Panel/Margin/VBox/TabRow/BestiaryTab
@onready var controls_tab: Button = $CenterContainer/Panel/Margin/VBox/TabRow/ControlsTab
@onready var bestiary_view: HBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/BestiaryView
@onready var controls_view: ScrollContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/ControlsView
@onready var list_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/BestiaryView/ListScroll/ListVBox
@onready var detail_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/BestiaryView/DetailMargin/DetailScroll/DetailVBox
@onready var controls_vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ContentPanel/ControlsView/ControlsMargin/ControlsVBox

var _font := preload("res://Baby Doll.otf")
var _browse_music_stream := preload("res://easy-breeze-ra-main-version-33378-02-16.mp3")
var _browse_music: AudioStreamPlayer = null
var is_open := false
var _was_paused_before := false
var _selected_id := ""
var _list_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dim_background.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.call_deferred("set", "pivot_offset", panel.size / 2.0)
	_populate_bestiary_list()
	_populate_controls()
	if Bestiary.get_entries().size() > 0:
		_select_entry(Bestiary.get_entries()[0]["id"])

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if is_open:
		return
	is_open = true
	_was_paused_before = get_tree().paused
	get_tree().paused = true
	visible = true
	dim_background.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_background, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_browse_music()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_stop_browse_music()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_background, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.15)
	await tween.finished
	visible = false
	get_tree().paused = _was_paused_before

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func _on_bestiary_tab_toggled(pressed: bool) -> void:
	if not pressed:
		return
	controls_tab.button_pressed = false
	bestiary_view.visible = true
	controls_view.visible = false

func _on_controls_tab_toggled(pressed: bool) -> void:
	if not pressed:
		return
	bestiary_tab.button_pressed = false
	bestiary_view.visible = false
	controls_view.visible = true

func _make_heading(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _populate_bestiary_list() -> void:
	for child in list_vbox.get_children():
		child.queue_free()
	_list_buttons.clear()

	for entry in Bestiary.get_entries():
		var btn := Button.new()
		btn.text = "  %s" % entry["name"]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.32, 0.2, 0.08, 1))
		btn.flat = true
		btn.pressed.connect(_select_entry.bind(entry["id"]))
		list_vbox.add_child(btn)
		_list_buttons[entry["id"]] = btn

func _select_entry(id: String) -> void:
	_selected_id = id
	for entry_id in _list_buttons:
		var btn: Button = _list_buttons[entry_id]
		btn.modulate = Color(1.0, 0.92, 0.7, 1.0) if entry_id == id else Color.WHITE

	var entry := Bestiary.get_entry(id)
	if entry.is_empty():
		return

	for child in detail_vbox.get_children():
		child.queue_free()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	detail_vbox.add_child(header)

	var icon_path: String = entry.get("icon", "")
	if icon_path != "":
		var tex := load(icon_path)
		if tex:
			var region: Rect2 = entry.get("icon_region", Rect2())
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(96, 96)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if region.size != Vector2.ZERO:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = region
				icon_rect.texture = atlas
			else:
				icon_rect.texture = tex
			header.add_child(icon_rect)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)
	title_col.add_child(_make_heading(entry["name"], 32, Color(0.32, 0.2, 0.08, 1)))

	var danger: int = entry.get("danger_level", 1)
	var danger_row := HBoxContainer.new()
	title_col.add_child(danger_row)
	var cat_label := _make_heading(String(entry.get("category", "")).to_upper(), 14, Color(0.5, 0.4, 0.25, 1))
	danger_row.add_child(cat_label)
	var sep := Label.new()
	sep.text = "   •   DANGER: "
	sep.add_theme_font_override("font", _font)
	sep.add_theme_font_size_override("font_size", 14)
	sep.add_theme_color_override("font_color", Color(0.5, 0.4, 0.25, 1))
	danger_row.add_child(sep)
	danger_row.add_child(_make_heading(DANGER_LABELS[clampi(danger, 1, 5)], 14, DANGER_COLORS[clampi(danger, 1, 5)]))

	detail_vbox.add_child(HSeparator.new())

	_add_detail_section("WHAT IS IT", entry.get("description", ""))
	_add_detail_section("BEHAVIOR", entry.get("behavior", ""))
	_add_detail_section("ATTACK PATTERN", entry.get("attack_pattern", ""))
	_add_detail_section("BEST STRATEGY", entry.get("strategy", ""))

func _add_detail_section(title: String, body: String) -> void:
	if body == "":
		return
	detail_vbox.add_child(_make_heading(title, 16, Color(0.55, 0.35, 0.1, 1)))
	var body_label := _make_heading(body, 18, Color(0.2, 0.14, 0.06, 1))
	body_label.custom_minimum_size = Vector2(560, 0)
	detail_vbox.add_child(body_label)

func _populate_controls() -> void:
	for child in controls_vbox.get_children():
		child.queue_free()

	for group in Bestiary.get_controls():
		controls_vbox.add_child(_make_heading(String(group["category"]).to_upper(), 22, Color(0.42, 0.28, 0.1, 1)))
		for row in group["rows"]:
			var row_box := HBoxContainer.new()
			row_box.add_theme_constant_override("separation", 12)
			controls_vbox.add_child(row_box)

			var key_label := _make_heading(row["label"], 17, Color(0.55, 0.15, 0.15, 1))
			key_label.custom_minimum_size = Vector2(210, 0)
			row_box.add_child(key_label)

			var detail_label := _make_heading(row["detail"], 17, Color(0.2, 0.14, 0.06, 1))
			detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_box.add_child(detail_label)
		controls_vbox.add_child(HSeparator.new())

func _start_browse_music() -> void:
	if _browse_music and is_instance_valid(_browse_music):
		return
	_browse_music = AudioStreamPlayer.new()
	_browse_music.stream = _browse_music_stream
	_browse_music.volume_db = -12.0
	_browse_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_browse_music)
	_browse_music.finished.connect(_browse_music.play)
	_browse_music.play()

func _stop_browse_music() -> void:
	if not _browse_music or not is_instance_valid(_browse_music):
		return
	var tween := create_tween()
	tween.tween_property(_browse_music, "volume_db", -40.0, 0.5)
	tween.tween_callback(_browse_music.queue_free)
	_browse_music = null
