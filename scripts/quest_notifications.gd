extends CanvasLayer

## Banner that announces a newly discovered quest.
##
## Lives on its own layer rather than inside a level so the notice looks the same
## everywhere a quest can open, and it is anchored just under the pause button,
## which every level pins to the top-right at the same spot. Unlocks that already
## happened in an earlier session are silent (see Quests._unlock_already_met), so
## only a quest the player just reached ever reaches here.
##
## The banner borrows the parchment-and-brown of the on-screen pause and field
## guide buttons so it reads as part of the same HUD, and is meant to feel like a
## reward rather than a status line: it pops and slides in, then idles with a
## pulsing glow and a slow bob until it slips away.

const FONT := preload("res://Baby Doll.otf")

const PANEL_WIDTH := 382.0
const PANEL_HEIGHT := 116.0
## The quest artwork sits to the left of the text, sized to sit comfortably in
## the banner next to two lines of text.
const ICON_SIZE := 60.0
## Pause button occupies x: right-65..right-20, y: 20..65, so the banner tucks in
## just beneath it, matching its right edge.
const RIGHT_MARGIN := 20.0
const TOP_OFFSET := 76.0
const SLIDE_OFFSET := 60.0
const SLIDE_TIME := 0.28
const POP_TIME := 0.42
const HOLD_TIME := 3.5
const FADE_TIME := 0.3
## Idle bob so the banner breathes rather than sitting frozen.
const BOB := 3.0
const BOB_TIME := 1.4
## The glow pulse swings the stylebox shadow between these sizes.
const GLOW_MIN := 12.0
const GLOW_MAX := 30.0
const GLOW_TIME := 0.8

## Pulled straight from the pause / field-guide button styleboxes (see the level
## scenes' StyleBoxFlat_pausebutton) so the banner matches the rest of the HUD:
## 2px dark-brown border on parchment, radius 8, dark-brown text, and the button
## hover tone for the bright phase of the glow.
const COLOR_BG := Color(0.8, 0.68, 0.46, 1)
const COLOR_BG_HOT := Color(0.97, 0.91, 0.78, 1)
const COLOR_BORDER := Color(0.42, 0.28, 0.14, 1)
const COLOR_BORDER_HOT := Color(0.58, 0.4, 0.2, 1)
const COLOR_GLOW := Color(1.0, 0.85, 0.45, 0.35)
const COLOR_GLOW_HOT := Color(1.0, 0.82, 0.42, 0.8)
const COLOR_TEXT := Color(0.32, 0.2, 0.08, 1)

## Completion banner glows green to feel celebratory.
const COLOR_COMPL_BG := Color(0.72, 0.78, 0.55, 1)
const COLOR_COMPL_BG_HOT := Color(0.88, 0.94, 0.72, 1)
const COLOR_COMPL_BORDER := Color(0.22, 0.42, 0.18, 1)
const COLOR_COMPL_BORDER_HOT := Color(0.36, 0.58, 0.3, 1)
const COLOR_COMPL_GLOW := Color(0.5, 1.0, 0.5, 0.35)
const COLOR_COMPL_GLOW_HOT := Color(0.6, 1.0, 0.6, 0.8)
const COLOR_COMPL_TEXT := Color(0.16, 0.28, 0.14, 1)

var _queue: Array[Dictionary] = []
var _showing := false
## The banner currently on screen and the tweens driving it, so a click can cut
## it short and open the guide without the idle animations outliving the panel.
var _active_panel: Control = null
var _active_tweens: Array[Tween] = []
var _dismissed := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 104

func _ready() -> void:
	Quests.quest_unlocked.connect(_on_quest_unlocked)
	Quests.quest_completed.connect(_on_quest_completed)

func _on_quest_unlocked(quest_id: String) -> void:
	var quest := Quests.get_quest(quest_id)
	_queue.append({"kind": "unlock", "id": quest_id, "title": str(quest.get("title", quest_id))})
	if not _showing:
		_show_next()

func _on_quest_completed(quest_id: String) -> void:
	var quest := Quests.get_quest(quest_id)
	_queue.append({"kind": "complete", "id": quest_id, "title": str(quest.get("title", quest_id))})
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	var title: String = item.get("title", "")
	var kind: String = item.get("kind", "unlock")
	var quest_id: String = item.get("id", "")
	await _display(title, kind, quest_id)
	_show_next()

## Draws one banner. kind "unlock" or "complete".
func _display(title: String, kind: String = "unlock", quest_id: String = "") -> void:
	var resting_left := -RIGHT_MARGIN - PANEL_WIDTH
	var resting_right := -RIGHT_MARGIN

	var is_complete := kind == "complete"

	var panel := PanelContainer.new()
	panel.name = "QuestUnlockBanner" if not is_complete else "QuestCompleteBanner"
	# Clickable: tapping the banner jumps to that quest in the field guide.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_banner_gui_input.bind(quest_id))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = resting_left + SLIDE_OFFSET
	panel.offset_right = resting_right + SLIDE_OFFSET
	panel.offset_top = TOP_OFFSET
	panel.offset_bottom = TOP_OFFSET + PANEL_HEIGHT
	panel.pivot_offset = Vector2(PANEL_WIDTH, PANEL_HEIGHT) * 0.5
	panel.scale = Vector2(0.82, 0.82)
	panel.modulate.a = 0.0

	var style := _make_panel_style(is_complete)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon_texture := Quests.get_quest_icon(quest_id)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Quests.get_quest_icon_tint(quest_id)
		row.add_child(icon)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	var header_text := "NEW QUEST UNLOCKED" if not is_complete else "QUEST COMPLETED!"
	var text_color := COLOR_COMPL_TEXT if is_complete else COLOR_TEXT
	var header := _make_label(header_text, 16, text_color)
	column.add_child(header)
	var title_label := _make_label(title, 22, text_color)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)

	_active_panel = panel
	_dismissed = false

	# Entry: slide in from the right, pop up to size, fade in.
	var intro := _track(create_tween())
	intro.set_parallel(true)
	intro.tween_property(panel, "modulate:a", 1.0, SLIDE_TIME)
	intro.tween_property(panel, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(panel, "offset_left", resting_left, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro.tween_property(panel, "offset_right", resting_right, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Idle: pulsing glow + slow bob.
	var glow_min := GLOW_MIN
	var glow_max := GLOW_MAX
	var glow_hot := COLOR_COMPL_GLOW_HOT if is_complete else COLOR_GLOW_HOT
	var glow := COLOR_COMPL_GLOW if is_complete else COLOR_GLOW
	var bg_hot := COLOR_COMPL_BG_HOT if is_complete else COLOR_BG_HOT
	var bg := COLOR_COMPL_BG if is_complete else COLOR_BG
	var border_hot := COLOR_COMPL_BORDER_HOT if is_complete else COLOR_BORDER_HOT
	var border := COLOR_COMPL_BORDER if is_complete else COLOR_BORDER

	var shimmer := _track(create_tween().set_loops())
	shimmer.tween_property(style, "shadow_size", glow_max, GLOW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer.parallel().tween_property(style, "bg_color", bg_hot, GLOW_TIME)
	shimmer.parallel().tween_property(style, "border_color", border_hot, GLOW_TIME)
	shimmer.parallel().tween_property(style, "shadow_color", glow_hot, GLOW_TIME)
	shimmer.tween_property(style, "shadow_size", glow_min, GLOW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer.parallel().tween_property(style, "bg_color", bg, GLOW_TIME)
	shimmer.parallel().tween_property(style, "border_color", border, GLOW_TIME)
	shimmer.parallel().tween_property(style, "shadow_color", glow, GLOW_TIME)

	var bob := _track(create_tween().set_loops())
	bob.tween_property(panel, "offset_top", TOP_OFFSET - BOB, BOB_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(panel, "offset_top", TOP_OFFSET + BOB, BOB_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Hold, but a click can cut it short so the guide opens right away.
	var hold_until := Time.get_ticks_msec() + int((HOLD_TIME + POP_TIME) * 1000.0)
	while not _dismissed and Time.get_ticks_msec() < hold_until:
		await get_tree().process_frame

	if not _dismissed:
		shimmer.kill()
		bob.kill()

		# Exit.
		var outro := _track(create_tween())
		outro.set_parallel(true)
		outro.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
		outro.tween_property(panel, "scale", Vector2(0.9, 0.9), FADE_TIME)
		outro.tween_property(panel, "offset_left", resting_left + SLIDE_OFFSET, FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		outro.tween_property(panel, "offset_right", resting_right + SLIDE_OFFSET, FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(FADE_TIME).timeout

	if is_instance_valid(panel):
		panel.queue_free()
	if _active_panel == panel:
		_active_panel = null
	_active_tweens.clear()

## Keeps a handle on every tween the banner starts so a click can stop them all.
func _track(tween: Tween) -> Tween:
	_active_tweens.append(tween)
	return tween

func _on_banner_gui_input(event: InputEvent, quest_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate_banner(quest_id)
	elif event is InputEventScreenTouch and event.pressed:
		_activate_banner(quest_id)

## Opening the quest in the log and clearing the banner are one action: the guide
## covers the banner anyway, and the banner has nothing left to say.
func _activate_banner(quest_id: String) -> void:
	SFX.play_ui("ui_click", -10.0, 1.15)
	_open_quest_in_guide(quest_id)
	_dismiss_current()

func _open_quest_in_guide(quest_id: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var popup := scene.get_node_or_null("InfoPopup")
	if popup and popup.has_method("open_quest"):
		popup.open_quest(quest_id)

func _dismiss_current() -> void:
	_dismissed = true
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	if _active_panel and is_instance_valid(_active_panel):
		_active_panel.queue_free()
	_active_panel = null

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_panel_style(is_complete: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if is_complete:
		sb.bg_color = COLOR_COMPL_BG
		sb.border_color = COLOR_COMPL_BORDER
		sb.shadow_color = COLOR_COMPL_GLOW
	else:
		sb.bg_color = COLOR_BG
		sb.border_color = COLOR_BORDER
		sb.shadow_color = COLOR_GLOW
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_size = GLOW_MIN
	sb.shadow_offset = Vector2.ZERO
	return sb
